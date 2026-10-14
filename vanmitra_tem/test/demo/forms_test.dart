import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';
import 'package:vanmitra_ai/demo/core/demo_core.dart';
import 'package:vanmitra_ai/demo/forms/demo_form_input.dart';
import 'package:vanmitra_ai/demo/forms/demo_form_rules.dart';

import 'demo_support.dart';

const _village = <String?>['ओझर', 'Ozhar', 'Jawhar', 'Palghar'];

Map<String, bool> _ok(Completeness c) => {for (final i in c.items) i.id: i.ok};

DemoError _invalid(void Function() f) {
  try {
    f();
  } on DemoError catch (e) {
    return e;
  }
  throw StateError('expected a validation error');
}

void main() {
  // ── Form B rules (tests/unit/test_form_b.py) ──────────────────────────────────

  group('Form B rules', () {
    test('the catalogue follows the printed form', () {
      expect(
        [for (final r in formBRights) (r.formItem, r.code, r.section)],
        [
          ('1', 'nistar', 'Section 3(1)(b)'),
          ('2', 'minor_forest_produce', 'Section 3(1)(c)'),
          ('3(a)', 'water_bodies', 'Section 3(1)(d)'),
          ('3(b)', 'grazing', 'Section 3(1)(d)'),
          ('3(c)', 'nomadic_pastoral_access', 'Section 3(1)(d)'),
          ('4', 'habitat', 'Section 3(1)(e)'),
          ('5', 'biodiversity_knowledge', 'Section 3(1)(k)'),
          ('6', 'other_traditional', 'Section 3(1)(l)'),
        ],
      );
      expect(formBRights.map((r) => r.code).toSet().length, 8);
    });

    Map<String, bool> check({
      List<String?> village = _village,
      List<String> names = const ['Ozhar Gram Sabha'],
      bool? fdst = true,
      bool? otfd = false,
      List<String> rights = const ['nistar'],
      List<String> evidence = const ['13(1)(a)', '13(1)(i)'],
    }) {
      final c = formBCompleteness(
        villageFields: village,
        claimantNames: names,
        isFdstCommunity: fdst,
        isOtfdCommunity: otfd,
        claimedRights: rights,
        evidenceRulesGiven: evidence,
      );
      expect(c.total, 5);
      return _ok(c);
    }

    test('complete form', () => expect(check().values.every((v) => v), isTrue));

    test('empty draft', () {
      expect(
        check(names: [], fdst: null, otfd: null, rights: [], evidence: []),
        {'B-1': false, 'B-2': false, 'B-3': true, 'B-4': false, 'B-5': false},
      );
    });

    test('both status questions must be answered; "No" is an answer', () {
      expect(check(otfd: null)['B-2'], isFalse);
      expect(check(fdst: false, otfd: false)['B-2'], isTrue);
    });

    test('Rule 11(1)(a) needs two evidences', () {
      expect(check(evidence: ['13(1)(a)'])['B-5'], isFalse);
      expect(check(evidence: ['13(1)(a)', '13(1)(a)'])['B-5'], isTrue);
    });

    test('a blank village field is incomplete', () {
      expect(check(village: ['ओझर', ' ', 'Jawhar', 'Palghar'])['B-3'], isFalse);
    });
  });

  group('Form B input', () {
    test('accepts a partial draft', () {
      final form = parseFormBInput({});
      expect(form['claimant_names'], isEmpty);
      expect(form['rights'], isEmpty);
    });

    test('strips and rejects blank names', () {
      expect(parseFormBInput({'claimant_names': ['  Ozhar  ']})['claimant_names'], ['Ozhar']);
      final e = _invalid(() => parseFormBInput({'claimant_names': ['   ']}));
      expect(e.status, 422);
      expect(e.error, 'VALIDATION_ERROR');
      expect(e.messageKey, 'validation.invalid');
      final err = (e.details['errors'] as List).single as Map;
      expect(err['type'], 'string_too_short');
      expect(err['loc'], ['body', 'claimant_names', 0]);
    });

    test('rejects duplicate names', () {
      final e = _invalid(() => parseFormBInput({'claimant_names': ['Ozhar', 'ozhar']}));
      expect(((e.details['errors'] as List).single as Map)['msg'], contains('duplicate'));
    });

    test('rejects an unknown right and an unknown rule', () {
      _invalid(() => parseFormBInput({'rights': {'mining': {'details': 'x'}}}));
      _invalid(() => parseFormBInput({'evidence': [{'rule_ref': '13(3)', 'description': 'x'}]}));
    });

    test('a claimed right needs details', () {
      _invalid(() => parseFormBInput({'rights': {'nistar': {'details': ''}}}));
      final e = _invalid(() => parseFormBInput({'rights': {'nistar': <String, dynamic>{}}}));
      expect(((e.details['errors'] as List).single as Map)['type'], 'missing');
    });

    test('the Maharashtra per-right details are optional and validated', () {
      final plain = parseFormBInput({'rights': {'nistar': {'details': 'Firewood'}}});
      final nistar = (plain['rights'] as Map)['nistar'] as Map;
      expect(nistar['boundaries'], isNull);
      expect(nistar['survey_compartment_numbers'], isEmpty);
      _invalid(() => parseFormBInput({'rights': {'nistar': {'details': 'x', 'total_area_ha': -5}}}));
      _invalid(() => parseFormBInput({
            'rights': {
              'nistar': {'details': 'x', 'boundaries': {'east': '   '}},
            },
          }));
    });
  });

  // ── Form C rules (tests/unit/test_form_c.py) ──────────────────────────────────

  group('Form C rules', () {
    const allSides = ['east', 'west', 'north', 'south'];

    Map<String, bool> check({
      MemberSheetCounts? members,
      String? area = 'Forest east of the village up to the Nagdevta stream',
      List<String> sides = allSides,
      int bordering = 1,
      List<String> evidence = const ['13(1)(a)', '13(1)(i)', '13(2)(b)'],
    }) {
      final c = formCCompleteness(
        villageFields: const ['ओझर', 'Ozar', 'Jawhar', 'Palghar'],
        members: members ?? memberSheetCounts(['st', 'other']),
        resolutionStatement: defaultResolutionStatement,
        areaDescription: area,
        landmarkSides: sides,
        borderingVillageCount: bordering,
        evidenceRulesGiven: evidence,
      );
      expect(c.total, 8);
      return _ok(c);
    }

    test('a complete Form C', () => expect(check().values.every((v) => v), isTrue));

    test('a new draft only has the registry and the default statement', () {
      final result = check(
        members: memberSheetCounts([]),
        area: null,
        sides: [],
        bordering: 0,
        evidence: [],
      );
      expect([for (final e in result.entries) if (e.value) e.key], ['FC-1', 'FC-3']);
    });

    test('the member sheet needs a few ST or OTFD', () {
      expect(check(members: memberSheetCounts(List.filled(5, 'other')))['FC-2'], isFalse);
      expect(check(members: memberSheetCounts([...List.filled(9, 'other'), 'otfd']))['FC-2'],
          isTrue);
    });

    test('all four boundaries need a landmark', () {
      expect(check(sides: ['east', 'west', 'north', 'within'])['FC-5'], isFalse);
    });

    test('a CFR claim needs Rule 13(2) evidence', () {
      final result = check(evidence: ['13(1)(a)', '13(1)(b)', '13(1)(i)']);
      expect(result['FC-7'], isTrue);
      expect(result['FC-8'], isFalse);
    });

    test('two general evidences are needed', () {
      final result = check(evidence: ['13(1)(a)', '13(2)(a)']);
      expect(result['FC-7'], isFalse);
      expect(result['FC-8'], isTrue);
    });

    test('member sheet counts', () {
      final counts = memberSheetCounts(['st', 'st', 'otfd', 'other']);
      expect((counts.total, counts.st, counts.otfd), (4, 2, 1));
    });
  });

  group('Form C input', () {
    test('accepts an empty draft', () {
      final form = parseFormCInput({});
      expect(form['resolution_statement'], isNull);
      expect(form['landmarks'], isEmpty);
      expect(form['khasra_compartment_numbers'], isEmpty);
      expect(form['pastoral_seasonal_use'], false);
    });

    test('rejects a bad side, kind and area', () {
      _invalid(() => parseFormCInput({
            'landmarks': [{'side': 'up', 'kind': 'pond', 'name': 'x'}],
          }));
      _invalid(() => parseFormCInput({
            'landmarks': [{'side': 'east', 'kind': 'mall', 'name': 'x'}],
          }));
      _invalid(() => parseFormCInput({'approx_area_ha': -1}));
    });

    test('a landmark needs a name', () {
      _invalid(() => parseFormCInput({
            'landmarks': [{'side': 'east', 'kind': 'pond', 'name': ' '}],
          }));
    });
  });

  group('Form A rules and input', () {
    Map<String, bool> check({
      List<String> names = const ['Ramesh'],
      String? address = 'Ozhar',
      bool? st = true,
      bool? otfd = false,
      List<String> claimed = const ['habitation'],
      List<String> evidence = const ['13(1)(a)', '13(1)(i)'],
      List<String?> village = _village,
    }) {
      final c = formACompleteness(
        villageFields: village,
        claimantNames: names,
        address: address,
        isScheduledTribe: st,
        isOtfd: otfd,
        claimed: claimed,
        evidenceRulesGiven: evidence,
      );
      expect(c.total, 6);
      return _ok(c);
    }

    test('catalogue follows the printed form', () {
      expect([for (final s in formAClaims) (s.formItem, s.code)], [
        ('1(a)', 'habitation'),
        ('1(b)', 'self_cultivation'),
        ('2', 'disputed_land'),
        ('3', 'patta_lease_grant'),
        ('4', 'in_situ_rehabilitation'),
        ('5', 'displaced_without_compensation'),
        ('6', 'forest_village'),
        ('7', 'other_traditional'),
      ]);
    });

    test('complete and empty', () {
      expect(check().values.every((v) => v), isTrue);
      expect(
        check(names: [], address: ' ', st: null, otfd: null, claimed: [], evidence: ['13(1)(a)']),
        {'FA-1': false, 'FA-2': false, 'FA-3': true, 'FA-4': false, 'FA-5': false, 'FA-6': false},
      );
      expect(check(village: ['ओझर', '', 'Jawhar', 'Palghar'])['FA-3'], isFalse);
    });

    test('input rules', () {
      expect(parseFormAInput({})['claims'], isEmpty);
      _invalid(() => parseFormAInput({'claimant_names': ['A', 'a']}));
      _invalid(() => parseFormAInput({'claims': {'mining': {'details': 'x'}}}));
      _invalid(() => parseFormAInput({'claims': {'habitation': {'details': 'x', 'extent_ha': -1}}}));
      _invalid(() => parseFormAInput({'claims': {'habitation': {'details': 'x', 'extent_ha': 10001}}}));
      _invalid(() => parseFormAInput({'family_members': [{'name': 'x', 'age': 131}]}));
      _invalid(() => parseFormAInput({'claimant_names': List.generate(21, (i) => 'n$i')}));
      _invalid(() => parseFormAInput({'is_otfd': 'maybe'}));
      expect(parseFormAInput({'is_otfd': 'yes'})['is_otfd'], isTrue);
      final e = _invalid(() => parseFormAInput(null));
      expect(((e.details['errors'] as List).single as Map)['loc'], ['body']);
    });

    test('path ids are checked like FastAPI', () {
      expect(parseUuidPath('case_id', '01A11846-11FC-7894-BCB3-597768083CEB'),
          '01a11846-11fc-7894-bcb3-597768083ceb');
      final e = _invalid(() => parseUuidPath('case_id', 'nope'));
      expect(((e.details['errors'] as List).single as Map)['loc'], ['path', 'case_id']);
    });
  });

  // ── routes ────────────────────────────────────────────────────────────────────

  group('through the demo server', () {
    late DemoHarness h;
    late String villager, villager2, gramSabha, sdo;
    const vid = DemoAccounts.villageId;

    setUp(() async {
      h = DemoHarness();
      villager = await h.login('9000000001');
      villager2 = await h.login('9000000002');
      gramSabha = await h.login('9000000003');
      sdo = await h.login('9000000005');
    });
    tearDown(() => h.dispose());

    Future<String> open(String type, {String? token}) async {
      final c = await h.call('POST', '/villages/$vid/cases',
          token: token ?? villager, body: {'claim_type': type});
      return c['id'] as String;
    }

    Map<String, dynamic> formABody() => {
          'claimant_names': ['Ramesh Gavit', 'Sunita Gavit'],
          'spouse_name': 'Sunita Gavit',
          'father_mother_name': 'Laxman Gavit',
          'address': 'Ozhar, Jawhar',
          'is_scheduled_tribe': true,
          'is_otfd': false,
          'spouse_is_scheduled_tribe': true,
          'family_members': [
            {'name': 'Asha', 'age': 12, 'relation': 'daughter'},
            {'name': 'Ravi'},
          ],
          'claims': {
            'self_cultivation': {'extent_ha': 1.234, 'details': 'Plot behind the school'},
            'habitation': {'extent_ha': 0.1, 'details': 'House plot'},
            'other_traditional': {'details': 'Grazing path'},
          },
          'evidence': [
            {'rule_ref': '13(1)(a)', 'description': '7/12 extract'},
            {'rule_ref': '13(1)(i)', 'description': 'Statement of elders'},
          ],
          'other_information': 'Cultivating since 1990',
        };

    Map<String, dynamic> formBBody() => {
          'claimant_names': ['Ozhar Gram Sabha'],
          'is_fdst_community': true,
          'is_otfd_community': false,
          'rights': {
            'grazing': {'details': 'Cattle graze on the hill'},
            'nistar': {
              'details': 'Firewood and bamboo',
              'items': ['bamboo'],
              'survey_compartment_numbers': ['12', '12', '13'],
              'total_area_ha': 40.556,
              'boundaries': {'east': 'Nagdevta stream', 'north': 'Road'},
              'annual_quantity': 'As needed',
            },
          },
          'evidence': [
            {'rule_ref': '13(1)(a)', 'description': 'Nistar patrak'},
            {'rule_ref': '13(2)(b)', 'description': 'Grazing ground record'},
          ],
          'other_information': 'None',
        };

    Map<String, dynamic> formCBody() => {
          'resolution_statement': 'We resolve.',
          'area_description': 'Forest east of the village',
          'approx_area_ha': 120.5,
          'pastoral_seasonal_use': true,
          'seasonal_use_details': 'Shepherds in summer',
          'landmarks': [
            {'side': 'east', 'kind': 'stream', 'name': 'Nagdevta stream'},
            {'side': 'west', 'kind': 'road', 'name': 'Village road', 'description': 'Tar road'},
            {'side': 'north', 'kind': 'hill', 'name': 'Kalsubai'},
            {'side': 'south', 'kind': 'pond', 'name': 'Gaon talav'},
            {'side': 'within', 'kind': 'sacred_grove', 'name': 'Devrai'},
          ],
          'khasra_compartment_numbers': ['C-12', 'C-12', 'C-14'],
          'bordering_villages': [
            {'name': 'Chambharshet', 'shares_resources': true, 'sharing_details': 'Grazing'},
            {'name': 'Dapchari'},
          ],
          'evidence': [
            {'rule_ref': '13(1)(a)', 'description': 'Gazetteer'},
            {'rule_ref': '13(1)(i)', 'description': 'Elders'},
            {'rule_ref': '13(2)(b)', 'description': 'Grazing ground'},
          ],
        };

    Future<void> submit(String caseId, String token) =>
        h.call('POST', '/cases/$caseId/submit', token: token);

    test('a new case starts with the empty form of its type', () async {
      final a = await open('ifr');
      final fa = await h.call('GET', '/cases/$a/form-a', token: villager);
      expect(fa['case_id'], a);
      expect(fa['state'], 'draft');
      expect(fa['editable'], isTrue);
      expect(fa['claimant_names'], isEmpty);
      expect(fa['claims'], hasLength(8));
      expect((fa['claims'] as List).every((c) => c['claimed'] == false), isTrue);
      expect(fa['total_extent_ha'], 0.0);
      expect(fa['extent_note'], isNull);
      expect(fa['header'], {
        'village_id': vid,
        'village_name_mr': 'ओझर',
        'village_name_en': 'Ozhar',
        'gram_panchayat': 'Ozhar',
        'taluka': 'Jawhar',
        'district': 'Palghar',
      });
      expect(fa['completeness']['done'], 1);
      expect(fa['completeness']['total'], 6);

      final b = await open('cr');
      final fb = await h.call('GET', '/cases/$b/form-b', token: villager);
      expect(fb['rights'], hasLength(8));
      expect(fb['completeness'], containsPair('done', 1));
      expect(fb['is_fdst_community'], isNull);

      final c = await open('cfr');
      final fc = await h.call('GET', '/cases/$c/form-c', token: villager);
      expect(fc['resolution_statement'], defaultResolutionStatement);
      expect(fc['pastoral_seasonal_use'], false);
      expect(fc['member_sheet'], containsPair('total', 5));
      expect(fc['member_sheet']['st'], 3);
      expect(fc['member_sheet']['otfd'], 1);
      expect(fc['completeness']['done'], 3); // registry, members, default statement
      expect(fc['completeness']['total'], 8);
    });

    test('Form A: save, read back, completeness grows, 4 ha note', () async {
      final id = await open('ifr');
      final saved = await h.call('PUT', '/cases/$id/form-a', token: villager, body: formABody());
      final read = await h.call('GET', '/cases/$id/form-a', token: villager);
      expect(read, saved);
      expect(saved['claimant_names'], ['Ramesh Gavit', 'Sunita Gavit']);
      expect(saved['family_members'], [
        {'seq': 1, 'name': 'Asha', 'age': 12, 'relation': 'daughter'},
        {'seq': 2, 'name': 'Ravi', 'age': null, 'relation': null},
      ]);
      final claims = saved['claims'] as List;
      expect([for (final c in claims) c['code']], [for (final s in formAClaims) s.code]);
      expect(claims[0]['claimed'], isTrue);
      expect(claims[0]['extent_ha'], 0.1);
      expect(claims[1]['extent_ha'], 1.23);
      expect(claims[7]['claimed'], isTrue);
      expect(claims[7]['extent_ha'], isNull);
      expect(claims[7]['details'], 'Grazing path');
      expect(claims[2]['claimed'], isFalse);
      expect(claims[2]['details'], isNull);
      expect(saved['total_extent_ha'], 1.33);
      expect(saved['extent_note'], isNull);
      expect(saved['evidence'], [
        {'seq': 1, 'rule_ref': '13(1)(a)', 'description': '7/12 extract'},
        {'seq': 2, 'rule_ref': '13(1)(i)', 'description': 'Statement of elders'},
      ]);
      expect(saved['completeness']['done'], 6);

      // one more claim pushes the total over 4 ha
      final body = formABody();
      (body['claims'] as Map)['disputed_land'] = {'extent_ha': 3.5, 'details': 'Disputed plot'};
      final over = await h.call('PUT', '/cases/$id/form-a', token: villager, body: body);
      expect(over['total_extent_ha'], 4.83);
      expect(over['extent_note'],
          'Recognition is limited to land under actual occupation and cannot exceed 4 ha [Section 4(6)].');

      // PUT replaces the draft: an empty body clears it again
      final cleared = await h.call('PUT', '/cases/$id/form-a', token: villager, body: {});
      expect(cleared['claimant_names'], isEmpty);
      expect(cleared['evidence'], isEmpty);
      expect(cleared['completeness']['done'], 1);

      // the case shows the claimant in its label
      await h.call('PUT', '/cases/$id/form-a', token: villager, body: formABody());
      final c = await h.call('GET', '/cases/$id', token: villager);
      expect(c['claimant_label'], 'Ramesh Gavit, Sunita Gavit');
    });

    test('Form B: save, read back and the Maharashtra per-right table', () async {
      final id = await open('cr');
      final saved = await h.call('PUT', '/cases/$id/form-b', token: villager, body: formBBody());
      expect(await h.call('GET', '/cases/$id/form-b', token: villager), saved);
      final rights = saved['rights'] as List;
      expect(rights, hasLength(8));
      final nistar = rights[0] as Map;
      expect(nistar['claimed'], isTrue);
      expect(nistar['items'], ['bamboo']);
      expect(nistar['survey_compartment_numbers'], ['12', '13']);
      expect(nistar['total_area_ha'], 40.56);
      expect(nistar['common_use_area_ha'], isNull);
      expect(nistar['boundaries'],
          {'east': 'Nagdevta stream', 'west': null, 'north': 'Road', 'south': null});
      expect(nistar['annual_quantity'], 'As needed');
      final grazing = rights[3] as Map;
      expect(grazing['claimed'], isTrue);
      expect(grazing['boundaries'], isNull);
      final mfp = rights[1] as Map;
      expect(mfp['claimed'], isFalse);
      expect(mfp['details'], isNull);
      expect(mfp['items'], isEmpty);
      expect(saved['completeness']['done'], 5);
      expect((await h.call('GET', '/cases/$id', token: villager))['claimant_label'],
          'Ozhar Gram Sabha');
    });

    test('Form C: save, default statement kept, de-duplicated khasra numbers', () async {
      final id = await open('cfr', token: gramSabha);
      final saved = await h.call('PUT', '/cases/$id/form-c', token: gramSabha, body: formCBody());
      expect(await h.call('GET', '/cases/$id/form-c', token: gramSabha), saved);
      expect(saved['resolution_statement'], 'We resolve.');
      expect(saved['approx_area_ha'], 120.5);
      expect(saved['khasra_compartment_numbers'], ['C-12', 'C-14']);
      expect((saved['landmarks'] as List).map((l) => l['seq']), [1, 2, 3, 4, 5]);
      expect(saved['landmarks'][1], {
        'seq': 2,
        'side': 'west',
        'kind': 'road',
        'name': 'Village road',
        'description': 'Tar road',
      });
      expect(saved['bordering_villages'], [
        {'seq': 1, 'name': 'Chambharshet', 'shares_resources': true, 'sharing_details': 'Grazing'},
        {'seq': 2, 'name': 'Dapchari', 'shares_resources': false, 'sharing_details': null},
      ]);
      expect(saved['completeness']['done'], 8);
      expect(saved['member_sheet']['members'], hasLength(5));
      // members are listed by name
      expect(saved['member_sheet']['members'][0],
          {'name': 'Demo Member 1', 'category': 'st'});

      final body = formCBody()..remove('resolution_statement');
      final again = await h.call('PUT', '/cases/$id/form-c', token: gramSabha, body: body);
      expect(again['resolution_statement'], defaultResolutionStatement);

      // a Gram Sabha claim is labelled by its village
      expect((await h.call('GET', '/cases/$id', token: gramSabha))['claimant_label'],
          'Gram Sabha, Ozhar');
    });

    test('who may see and edit a form', () async {
      final id = await open('ifr');
      // another villager and the officials do not see a draft
      for (final t in [villager2, gramSabha, sdo]) {
        final e = await h.fails('GET', '/cases/$id/form-a', token: t);
        expect(e.statusCode, 404);
        expect(e.error, 'CASE_NOT_FOUND');
        expect((await h.fails('PUT', '/cases/$id/form-a', token: t, body: {})).statusCode, 404);
      }
      await h.call('PUT', '/cases/$id/form-a', token: villager, body: formABody());

      // filed: the Gram Sabha reads it but cannot change it; the claimant cannot either
      await submit(id, villager);
      final seen = await h.call('GET', '/cases/$id/form-a', token: gramSabha);
      expect(seen['editable'], isFalse);
      expect(seen['state'], 'gs_review');
      final gsPut = await h.fails('PUT', '/cases/$id/form-a', token: gramSabha, body: {});
      expect(gsPut.statusCode, 403);
      expect(gsPut.error, 'ONLY_CLAIMANT_CAN_EDIT');
      final mine = await h.fails('PUT', '/cases/$id/form-a', token: villager, body: formABody());
      expect(mine.statusCode, 409);
      expect(mine.error, 'CASE_NOT_EDITABLE');
      expect(mine.messageKey, 'case.not_editable');
      expect(mine.details, {'state': 'gs_review'});
      expect((await h.call('GET', '/cases/$id/form-a', token: villager))['editable'], isFalse);
      // the SDO does not see it until it reaches the SDO
      expect((await h.fails('GET', '/cases/$id/form-a', token: sdo)).statusCode, 404);
      // the form text is unchanged
      expect(seen['claimant_names'], ['Ramesh Gavit', 'Sunita Gavit']);

      // sent back: the claimant edits it again
      await h.call('POST', '/cases/$id/return',
          token: gramSabha, body: {'remarks': 'Please add the address'});
      final back = await h.call('GET', '/cases/$id/form-a', token: villager);
      expect(back['editable'], isTrue);
      final fixed = formABody()..['address'] = 'New address';
      expect((await h.call('PUT', '/cases/$id/form-a', token: villager, body: fixed))['address'],
          'New address');
    });

    test('the wrong form answers 409', () async {
      final a = await open('ifr');
      final b = await open('cr');
      final c = await open('cfr');
      final wrong = <(String, String, String)>[
        (a, 'form-b', 'NOT_A_FORM_B_CASE'),
        (a, 'form-c', 'NOT_A_FORM_C_CASE'),
        (b, 'form-a', 'NOT_A_FORM_A_CASE'),
        (b, 'form-c', 'NOT_A_FORM_C_CASE'),
        (c, 'form-a', 'NOT_A_FORM_A_CASE'),
        (c, 'form-b', 'NOT_A_FORM_B_CASE'),
      ];
      for (final (id, form, error) in wrong) {
        for (final method in ['GET', 'PUT']) {
          final e = await h.fails(method, '/cases/$id/$form',
              token: villager, body: method == 'PUT' ? <String, dynamic>{} : null);
          expect(e.statusCode, 409, reason: '$method $form');
          expect(e.error, error);
          expect(e.messageKey, 'case.wrong_form');
        }
      }
      expect((await h.fails('GET', '/cases/$a/form-b', token: villager)).details,
          {'claim_type': 'ifr'});
    });

    test('bad input answers 422 and saves nothing', () async {
      final id = await open('ifr');
      await h.call('PUT', '/cases/$id/form-a', token: villager, body: formABody());

      Future<List> errorsOf(Object? body) async {
        final e = await h.fails('PUT', '/cases/$id/form-a', token: villager, body: body);
        expect(e.statusCode, 422);
        expect(e.error, 'VALIDATION_ERROR');
        expect(e.messageKey, 'validation.invalid');
        return e.details!['errors'] as List;
      }

      final blank = await errorsOf({'claimant_names': ['  ']});
      expect(blank.single['loc'], ['body', 'claimant_names', 0]);
      expect(blank.single['type'], 'string_too_short');
      expect((await errorsOf({'claimant_names': ['Ram', 'RAM']})).single['type'], 'value_error');
      final badCode = await errorsOf({'claims': {'mining': {'details': 'x'}}});
      expect(badCode.single['loc'], ['body', 'claims', 'mining', '[key]']);
      expect(badCode.single['type'], 'enum');
      final noDetails = await errorsOf({'claims': {'habitation': {'extent_ha': 1}}});
      expect(noDetails.single['loc'], ['body', 'claims', 'habitation', 'details']);
      expect(noDetails.single['type'], 'missing');
      expect((await errorsOf({'claims': {'habitation': {'details': 'x', 'extent_ha': -1}}}))
              .single['type'],
          'greater_than_equal');
      expect((await errorsOf({'address': 5})).single['type'], 'string_type');
      expect((await errorsOf({'evidence': [{'rule_ref': '13(3)', 'description': 'x'}]})).single['loc'],
          ['body', 'evidence', 0, 'rule_ref']);
      expect((await errorsOf(['not', 'an', 'object'])).single['type'], 'model_attributes_type');
      expect((await errorsOf(null)).single['type'], 'missing');
      // several problems are all reported
      expect(await errorsOf({'claimant_names': [''], 'address': ''}), hasLength(2));

      // nothing was saved
      final read = await h.call('GET', '/cases/$id/form-a', token: villager);
      expect(read['address'], 'Ozhar, Jawhar');
      expect(read['claimant_names'], ['Ramesh Gavit', 'Sunita Gavit']);

      // Form B and C
      final idB = await open('cr');
      expect((await h.fails('PUT', '/cases/$idB/form-b', token: villager, body: {
        'rights': {'nistar': {'details': ''}},
      }))
          .statusCode, 422);
      final idC = await open('cfr');
      expect((await h.fails('PUT', '/cases/$idC/form-c', token: villager, body: {
        'landmarks': [{'side': 'up', 'kind': 'pond', 'name': 'x'}],
      }))
          .statusCode, 422);
      // a path id that is not a UUID is checked before the case is looked up
      final bad = await h.fails('GET', '/cases/not-a-uuid/form-a', token: villager);
      expect(bad.statusCode, 422);
      expect(bad.details!['errors'][0]['loc'], ['path', 'case_id']);
    });

    test('an unknown case is 404 and a missing sign-in is 401', () async {
      const ghost = '00000000-0000-4000-8000-0000000000ff';
      expect((await h.fails('GET', '/cases/$ghost/form-a', token: villager)).statusCode, 404);
      final id = await open('ifr');
      expect((await h.fails('GET', '/cases/$id/form-a')).statusCode, 401);
      expect((await h.fails('PUT', '/cases/$id/form-a', body: {})).statusCode, 401);
      expect((await h.fails('GET', '/forms/form-b/fields')).statusCode, 401);
      expect((await h.fails('GET', '/forms/form-c/fields')).statusCode, 401);
    });

    test('saving moves the case updated_at only when something changed', () async {
      final id = await open('cr');
      final created = (await h.call('GET', '/cases/$id', token: villager))['updated_at'];
      h.advance(const Duration(minutes: 5));
      await h.call('PUT', '/cases/$id/form-b', token: villager, body: {});
      expect((await h.call('GET', '/cases/$id', token: villager))['updated_at'], created);
      await h.call('PUT', '/cases/$id/form-b', token: villager, body: formBBody());
      expect((await h.call('GET', '/cases/$id', token: villager))['updated_at'],
          isNot(created));
    });

    test('Form B field description', () async {
      final f = await h.call('GET', '/forms/form-b/fields', token: villager);
      expect(f['form'], 'Form B: Claim Form for Community Rights');
      expect(f['rule'], 'Rule 11(1)(a) and (4)');
      expect(f['rights'], hasLength(8));
      expect(f['rights'][2],
          {'code': 'water_bodies', 'form_item': '3(a)', 'label_en': 'Community rights: uses or entitlements (fish, water bodies), if any', 'section': 'Section 3(1)(d)'});
      expect(f['evidence_rules'], hasLength(14));
      expect(f['evidence_rules'].first, '13(1)(a)');
      expect(f['evidence_rules'].last, '13(2)(e)');
      expect(f['min_evidence_items'], 2);
    });

    test('Form C field description', () async {
      final f = await h.call('GET', '/forms/form-c/fields', token: gramSabha);
      expect(f['form'], 'Form C: Claim Form for Rights to Community Forest Resource');
      expect(f['rule'], 'Section 3(1)(i); Rule 11(1) and (4)');
      expect(f['default_resolution_statement'], defaultResolutionStatement);
      expect(f['boundary_sides'], ['east', 'west', 'north', 'south', 'within']);
      expect(f['landmark_kinds'], hasLength(12));
      expect(f['evidence_rules'], hasLength(14));
      expect(f['min_general_evidence'], 2);
      expect(f['min_cfr_evidence'], 1);
    });
  });
}
