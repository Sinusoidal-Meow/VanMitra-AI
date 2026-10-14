import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';
import 'package:vanmitra_ai/demo/core/demo_cases.dart';
import 'package:vanmitra_ai/demo/core/demo_core.dart';
import 'package:vanmitra_ai/demo/evidence/readiness.dart';

import 'demo_support.dart';

// ── readiness: tests/unit/test_readiness.py ────────────────────────────────────

ReadinessInput _input({
  String claimType = ClaimTypes.cfr,
  int verifiedGeneral = 2,
  int verifiedCfr = 1,
  bool signedElderStatement = true,
  bool acknowledged = true,
  bool boundaryGsApproved = true,
  Object? segmentsWithoutLandmark = 0,
  bool verificationComplete = true,
  bool quorumPassed = true,
  int adjacentTotal = 2,
  int adjacentIntimated = 2,
  int openDisputes = 0,
}) =>
    ReadinessInput(
      claimType: claimType,
      verifiedGeneral: verifiedGeneral,
      verifiedCfr: verifiedCfr,
      signedElderStatement: signedElderStatement,
      acknowledged: acknowledged,
      boundaryGsApproved: boundaryGsApproved,
      segmentsWithoutLandmark: segmentsWithoutLandmark as int?,
      verificationComplete: verificationComplete,
      quorumPassed: quorumPassed,
      adjacentTotal: adjacentTotal,
      adjacentIntimated: adjacentIntimated,
      openDisputes: openDisputes,
    );

Set<String> _failing(ReadinessInput r) => {
      for (final i in readiness(r).items)
        if (!i.ok) i.id,
    };

void main() {
  group('readiness R1-R10 (domain)', () {
    test('a complete CFR case passes all ten', () {
      final c = readiness(_input());
      expect((c.done, c.total), (10, 10));
    });

    final cases = <(String, ReadinessInput, Set<String>)>[
      ('verified_general 1', _input(verifiedGeneral: 1), {'R1'}),
      ('verified_cfr 0', _input(verifiedCfr: 0), {'R2'}),
      ('boundary not approved', _input(boundaryGsApproved: false), {'R3'}),
      ('no boundary mapped', _input(segmentsWithoutLandmark: null), {'R4'}),
      ('2 segments without landmark', _input(segmentsWithoutLandmark: 2), {'R4'}),
      ('verification not complete', _input(verificationComplete: false), {'R5'}),
      ('no signed elder statement', _input(signedElderStatement: false), {'R6'}),
      ('quorum not passed', _input(quorumPassed: false), {'R7'}),
      ('1 of 2 neighbours intimated', _input(adjacentIntimated: 1), {'R8'}),
      ('no neighbours listed', _input(adjacentTotal: 0, adjacentIntimated: 0), {'R8'}),
      ('not acknowledged', _input(acknowledged: false), {'R9'}),
      ('an open dispute', _input(openDisputes: 1), {'R10'}),
    ];
    for (final (name, input, fails) in cases) {
      test('each check fails on its own: $name', () => expect(_failing(input), fails));
    }

    test('three general evidences stand in for the elder statement', () {
      expect(
        _failing(_input(signedElderStatement: false, verifiedGeneral: 3)),
        isNot(contains('R6')),
      );
    });

    test('non-CFR claims get only the checks that apply', () {
      final c = readiness(_input(claimType: ClaimTypes.ifr));
      expect([for (final i in c.items) i.id], ['R1', 'R5', 'R6', 'R7', 'R9']);
    });

    test('GPS and satellite are never substitutable', () {
      expect(isSubstitutableKind('gps_point'), isFalse);
      expect(isSubstitutableKind('satellite'), isFalse);
      expect(isSubstitutableKind('elder_statement'), isTrue);
    });

    test('add_months clamps to the end of the month', () {
      expect(dateOnly(addMonths(DateTime.utc(2026, 1, 15), 3)), '2026-04-15');
      expect(dateOnly(addMonths(DateTime.utc(2026, 11, 30), 3)), '2027-02-28');
      expect(dateOnly(addMonths(DateTime.utc(2027, 11, 30), 3)), '2028-02-29');
      expect(dateOnly(addMonths(DateTime.utc(2026, 12, 31), 1)), '2027-01-31');
    });

    test('rule 13(1) is general, 13(2) is not', () {
      expect(isGeneralRule('13(1)(a)'), isTrue);
      expect(isGeneralRule('13(2)(a)'), isFalse);
    });
  });

  // ── routes ───────────────────────────────────────────────────────────────────

  group('evidence, readiness, media, acknowledgement, documents (routes)', () {
    late DemoHarness h;
    late String villager; // 9000000001
    late String villager2; // 9000000002
    late String gs; // 9000000003
    late String sdo; // 9000000005
    const village = DemoAccounts.villageId;

    setUp(() async {
      h = DemoHarness();
      villager = await h.login('9000000001');
      villager2 = await h.login('9000000002');
      gs = await h.login('9000000003');
      sdo = await h.login('9000000005');
    });
    tearDown(() => h.dispose());

    Future<String> newCase(String claimType, {String? token}) async {
      final c = await h.call('POST', '/villages/$village/cases',
          token: token ?? villager, body: {'claim_type': claimType});
      return (c as Map)['id'] as String;
    }

    Future<Map<String, dynamic>> addEvidence(String caseId, Map<String, dynamic> body,
        {String? token}) async {
      final r = await h.call('POST', '/cases/$caseId/evidence', token: token ?? villager, body: body);
      return Map<String, dynamic>.from(r as Map);
    }

    Future<void> submit(String caseId, {String? token}) =>
        h.call('POST', '/cases/$caseId/submit', token: token ?? villager);

    Map<String, dynamic> general(String desc, {String rule = '13(1)(a)', String kind = 'document_scan'}) =>
        {'rule_ref': rule, 'kind': kind, 'description': desc};

    Future<Map<String, dynamic>> upload(String token,
        {List<int>? bytes, String mime = 'application/pdf', String name = '712.pdf',
        Map<String, String> fields = const {}}) async {
      final b = bytes ?? utf8.encode('%PDF-1.4 test scan of a 7/12 extract');
      final r = await h.call('UPLOAD', '/media', token: token, body: {
        'file_base64': base64Encode(b),
        'filename': name,
        'mime': mime,
        'fields': fields,
      });
      return Map<String, dynamic>.from(r as Map);
    }

    Future<Map<String, dynamic>> readinessOf(String caseId, {String? token}) async =>
        Map<String, dynamic>.from(
            await h.call('GET', '/cases/$caseId/readiness', token: token ?? villager) as Map);

    test('every route needs a sign-in', () async {
      final id = await newCase('ifr');
      for (final (method, path) in [
        ('GET', '/cases/$id/evidence'),
        ('POST', '/cases/$id/evidence'),
        ('GET', '/cases/$id/readiness'),
        ('GET', '/cases/$id/acknowledgement'),
        ('GET', '/cases/$id/documents/g4'),
        ('UPLOAD', '/media'),
        ('GET', '/media/${DemoAccounts.villageId}'),
        ('BYTES', '/media/${DemoAccounts.villageId}/file'),
      ]) {
        final e = await h.fails(method, path);
        expect(e.statusCode, 401, reason: '$method $path');
        expect(e.error, 'NOT_AUTHENTICATED');
      }
    });

    group('evidence', () {
      test('the claimant adds evidence while drafting; the item has the EvidenceOut shape', () async {
        final id = await newCase('ifr');
        final e = await addEvidence(id, {
          ...general('  7/12 extract  '),
          'source_office': 'Talathi, Ozhar sajja',
          'ref_no': 'KH-210',
          'doc_date': '1980-05-01',
        });
        expect(e.keys.toSet(), {
          'id', 'rule_ref', 'kind', 'description', 'media_id', 'source_office', 'ref_no',
          'doc_date', 'gps_lat', 'gps_lon', 'gps_accuracy_m', 'is_substitutable',
          'elder_member_id', 'transcript', 'signed_scan_media_id', 'supersedes_id',
          'superseded', 'correction_reason', 'verified', 'verifications', 'created_at',
        });
        expect(e['description'], '7/12 extract'); // trimmed
        expect(e['rule_ref'], '13(1)(a)');
        expect(e['kind'], 'document_scan');
        expect(e['is_substitutable'], isTrue);
        expect(e['superseded'], isFalse);
        expect(e['verified'], isFalse);
        expect(e['verifications'], isEmpty);
        expect(e['supersedes_id'], isNull);
        expect(e['media_id'], isNull);
        expect(e['doc_date'], '1980-05-01');
        expect(e['created_at'], h.now.toIso8601String());

        final list = await h.call('GET', '/cases/$id/evidence', token: villager) as List;
        expect(list, hasLength(1));
        expect((list.single as Map)['id'], e['id']);
      });

      test('GPS and satellite items are never substitutable (BR-06); a GPS point needs coordinates',
          () async {
        final id = await newCase('ifr');
        final gps = await addEvidence(id, {
          ...general('Bund corner', rule: '13(1)(c)', kind: 'gps_point'),
          'gps_lat': 19.91,
          'gps_lon': 73.21,
          'gps_accuracy_m': 6,
        });
        expect(gps['is_substitutable'], isFalse);
        expect(gps['gps_lat'], 19.91);
        expect(gps['gps_accuracy_m'], 6.0);
        final sat = await addEvidence(id, general('Imagery', rule: '13(1)(c)', kind: 'satellite'));
        expect(sat['is_substitutable'], isFalse);

        final e = await h.fails('POST', '/cases/$id/evidence',
            token: villager, body: general('No coordinates', rule: '13(1)(c)', kind: 'gps_point'));
        expect(e.statusCode, 422);
        expect(e.error, 'GPS_POINT_NEEDS_COORDINATES');
        expect(e.messageKey, 'evidence.gps_needs_coordinates');
      });

      test('bad input is a 422 VALIDATION_ERROR with the list of errors', () async {
        final id = await newCase('ifr');
        for (final body in <Map<String, dynamic>>[
          {...general(''), 'description': '   '},
          {...general('x'), 'rule_ref': '13(9)(z)'},
          {...general('x'), 'kind': 'hologram'},
          {'rule_ref': '13(1)(a)', 'kind': 'photo'},
          {...general('x'), 'gps_lat': 91},
          {...general('x'), 'gps_lon': -181},
          {...general('x'), 'gps_accuracy_m': -1},
          {...general('x'), 'doc_date': '31-12-2020'},
          {...general('x'), 'doc_date': '2026-02-30'},
          {...general('x'), 'media_id': 'not-a-uuid'},
          {...general('x'), 'description': 'a' * 4001},
        ]) {
          final e = await h.fails('POST', '/cases/$id/evidence', token: villager, body: body);
          expect(e.statusCode, 422, reason: '$body');
          expect(e.error, 'VALIDATION_ERROR');
          expect(e.messageKey, 'validation.invalid');
          expect((e.details!['errors'] as List), isNotEmpty);
        }
        final notJson = await h.fails('POST', '/cases/$id/evidence', token: villager, body: 'x');
        expect(notJson.statusCode, 422);
        final badId = await h.fails('GET', '/cases/not-a-uuid/evidence', token: villager);
        expect(badId.statusCode, 422);
        expect((await h.call('GET', '/cases/$id/evidence', token: villager) as List), isEmpty);
      });

      test('an elder statement needs rule 13(1)(i) and an elder on the roster', () async {
        final id = await newCase('cfr');
        final e1 = await h.fails('POST', '/cases/$id/evidence',
            token: villager,
            body: {...general('Statement', rule: '13(1)(a)', kind: 'elder_statement')});
        expect((e1.statusCode, e1.error), (422, 'ELDER_STATEMENT_FIELDS'));
        final e2 = await h.fails('POST', '/cases/$id/evidence',
            token: villager,
            body: {
              ...general('Statement', rule: '13(1)(i)', kind: 'elder_statement'),
              'elder_member_id': '01900000-0000-7000-8000-000000000009',
              'transcript': 'We used this forest',
            });
        expect((e2.statusCode, e2.error), (422, 'ELDER_NOT_IN_ROSTER'));
      });

      test('media must be the caller\'s own upload', () async {
        final id = await newCase('ifr');
        final theirs = await upload(villager2);
        final e = await h.fails('POST', '/cases/$id/evidence',
            token: villager, body: {...general('Scan'), 'media_id': theirs['id']});
        expect((e.statusCode, e.error, e.messageKey), (422, 'MEDIA_NOT_YOURS', 'evidence.media_not_yours'));
        expect(e.details!['media_id'], theirs['id']);
        final unknown = await h.fails('POST', '/cases/$id/evidence',
            token: villager,
            body: {...general('Scan'), 'signed_scan_media_id': '01900000-0000-7000-8000-000000000001'});
        expect(unknown.error, 'MEDIA_NOT_YOURS');

        final mine = await upload(villager);
        final ok = await addEvidence(id, {...general('Scan'), 'media_id': mine['id']});
        expect(ok['media_id'], mine['id']);
      });

      test('who can see and add: other villagers and the Gram Sabha cannot see a draft', () async {
        final id = await newCase('ifr');
        for (final t in [villager2, gs, sdo]) {
          final e = await h.fails('GET', '/cases/$id/evidence', token: t);
          expect((e.statusCode, e.error), (404, 'CASE_NOT_FOUND'));
          final p = await h.fails('POST', '/cases/$id/evidence', token: t, body: general('x'));
          expect(p.statusCode, 404);
        }
        final missing = await h.fails('GET', '/cases/01900000-0000-7000-8000-000000000001/evidence',
            token: villager);
        expect(missing.statusCode, 404);
      });

      test('after filing: the Gram Sabha may add, the claimant may not', () async {
        final id = await newCase('ifr');
        await addEvidence(id, general('First'));
        await submit(id);
        final late = await h.fails('POST', '/cases/$id/evidence', token: villager, body: general('Late'));
        expect((late.statusCode, late.error, late.messageKey),
            (403, 'CANNOT_ADD_EVIDENCE_NOW', 'evidence.cannot_add_now'));
        expect(late.details!['state'], 'gs_review');
        final added = await addEvidence(id, general('Seen by the Gram Sabha', rule: '13(1)(g)'), token: gs);
        expect(added['description'], 'Seen by the Gram Sabha');
        // the SDO cannot see a case still with the Gram Sabha
        expect((await h.fails('GET', '/cases/$id/evidence', token: sdo)).statusCode, 404);
        // the Gram Sabha sees the list, the claimant too
        for (final t in [gs, villager]) {
          expect(await h.call('GET', '/cases/$id/evidence', token: t) as List, hasLength(2));
        }
      });

      test('a correction supersedes the old record (BR-15)', () async {
        final id = await newCase('ifr');
        final old = await addEvidence(id, general('Old village well', rule: '13(1)(g)', kind: 'photo'));
        final badReason = await h.fails('POST', '/cases/$id/evidence/${old['id']}/correct',
            token: villager,
            body: {...general('Old village well (1952)', rule: '13(1)(g)', kind: 'photo'), 'correction_reason': 'x'});
        expect(badReason.statusCode, 422);
        final noReason = await h.fails('POST', '/cases/$id/evidence/${old['id']}/correct',
            token: villager,
            body: general('Old village well (1952)', rule: '13(1)(g)', kind: 'photo'));
        expect(noReason.statusCode, 422);

        final fixed = Map<String, dynamic>.from(await h.call(
            'POST', '/cases/$id/evidence/${old['id']}/correct',
            token: villager,
            body: {
              ...general('Old village well (1952)', rule: '13(1)(g)', kind: 'photo'),
              'correction_reason': 'Year of construction added',
            }) as Map);
        expect(fixed['supersedes_id'], old['id']);
        expect(fixed['correction_reason'], 'Year of construction added');

        final current = (await h.call('GET', '/cases/$id/evidence', token: villager) as List).cast<Map>();
        expect([for (final e in current) e['id']], [fixed['id']]);
        final every = (await h.call('GET', '/cases/$id/evidence?include_superseded=true', token: villager)
                as List)
            .cast<Map>();
        expect(every, hasLength(2));
        expect(every.firstWhere((e) => e['id'] == old['id'])['superseded'], isTrue);
        expect(every.firstWhere((e) => e['id'] == fixed['id'])['superseded'], isFalse);
        expect((await h.fails('GET', '/cases/$id/evidence?include_superseded=maybe', token: villager)).statusCode,
            422);

        final again = await h.fails('POST', '/cases/$id/evidence/${old['id']}/correct',
            token: villager,
            body: {...general('Again', rule: '13(1)(g)', kind: 'photo'), 'correction_reason': 'Second try'});
        expect((again.statusCode, again.error), (409, 'ALREADY_SUPERSEDED'));
        final unknown = await h.fails('POST',
            '/cases/$id/evidence/01900000-0000-7000-8000-000000000001/correct',
            token: villager,
            body: {...general('x'), 'correction_reason': 'No such item'});
        expect((unknown.statusCode, unknown.error), (404, 'EVIDENCE_NOT_FOUND'));
      });

      test('verification: only the Gram Sabha, only while it reviews, once each', () async {
        final id = await newCase('ifr');
        final item = await addEvidence(id, general('7/12 extract'));
        final path = '/cases/$id/evidence/${item['id']}/verify';

        // a draft is not visible to the Gram Sabha
        expect((await h.fails('POST', path, token: gs)).statusCode, 404);
        // the claimant is not the Gram Sabha
        final own = await h.fails('POST', path, token: villager);
        expect((own.statusCode, own.error, own.messageKey), (403, 'NOT_YOUR_LEVEL', 'workflow.not_your_level'));

        await submit(id);
        expect((await h.fails('POST', path, token: villager)).error, 'NOT_YOUR_LEVEL');
        final badRemarks = await h.fails('POST', path, token: gs, body: {'remarks': ''});
        expect(badRemarks.statusCode, 422);
        final notThere = await h.fails('POST',
            '/cases/$id/evidence/01900000-0000-7000-8000-000000000001/verify',
            token: gs);
        expect((notThere.statusCode, notThere.error), (404, 'EVIDENCE_NOT_FOUND'));

        final v = Map<String, dynamic>.from(
            await h.call('POST', path, token: gs, body: {'remarks': '  Seen on site '}) as Map);
        expect(v['verified'], isTrue);
        final verifications = (v['verifications'] as List).cast<Map>();
        expect(verifications, hasLength(1));
        expect(verifications.single.keys.toSet(), {'verified_by_name', 'remarks', 'at'});
        expect(verifications.single['verified_by_name'], 'Demo Gram Sabha (Ozhar)');
        expect(verifications.single['remarks'], 'Seen on site');
        expect(verifications.single['at'], h.now.toIso8601String());

        final again = await h.fails('POST', path, token: gs);
        expect((again.statusCode, again.error, again.messageKey),
            (409, 'ALREADY_VERIFIED', 'evidence.already_verified'));

        // the verification shows to the claimant too
        final list = (await h.call('GET', '/cases/$id/evidence', token: villager) as List).cast<Map>();
        expect(list.single['verified'], isTrue);
      });

      test('verification needs the case to be under Gram Sabha review', () async {
        final id = await newCase('ifr');
        final item = await addEvidence(id, general('7/12 extract'));
        await submit(id);
        await h.call('POST', '/cases/$id/approve', token: gs); // now with the SDO
        // the SDO is not the Gram Sabha
        final bySdo = await h.fails('POST', '/cases/$id/evidence/${item['id']}/verify', token: sdo);
        expect(bySdo.error, 'NOT_YOUR_LEVEL');
        // the Gram Sabha still sees the case (it reached them) but it is no longer in their review
        final late = await h.fails('POST', '/cases/$id/evidence/${item['id']}/verify', token: gs);
        expect((late.statusCode, late.error, late.messageKey),
            (409, 'NOT_UNDER_GS_REVIEW', 'evidence.not_under_gs_review'));
      });

      test('a superseded item cannot be verified', () async {
        final id = await newCase('ifr');
        final old = await addEvidence(id, general('Old'));
        final fixed = await h.call('POST', '/cases/$id/evidence/${old['id']}/correct',
            token: villager, body: {...general('New'), 'correction_reason': 'Wrong description'});
        await submit(id);
        final e = await h.fails('POST', '/cases/$id/evidence/${old['id']}/verify', token: gs);
        expect((e.statusCode, e.error), (409, 'ALREADY_SUPERSEDED'));
        final ok = await h.call('POST', '/cases/$id/evidence/${(fixed as Map)['id']}/verify', token: gs);
        expect((ok as Map)['verified'], isTrue);
      });
    });

    group('readiness', () {
      test('Form A gets R1, R5, R6, R7, R9 and the answer has the ReadinessOut shape', () async {
        final id = await newCase('ifr');
        final r = await readinessOf(id);
        expect(r.keys.toSet(), {'done', 'total', 'items', 'case_id', 'claim_type'});
        expect(r['case_id'], id);
        expect(r['claim_type'], 'ifr');
        expect(r['total'], 5);
        expect(r['done'], 0);
        final items = (r['items'] as List).cast<Map>();
        expect([for (final i in items) i['id']], ['R1', 'R5', 'R6', 'R7', 'R9']);
        expect(items.first.keys.toSet(), {'id', 'ok', 'form_item', 'rule', 'message_key'});
        expect(items.first['message_key'], 'readiness.r1_two_general_evidences');
        expect(items.first['rule'], 'Rule 11(1)(a), 13(3)');
        expect(items.first['form_item'], 'evidence');
        // no numeric score anywhere (rule C2): only done/total counts
        expect(r.containsKey('score'), isFalse);
      });

      test('a CFR claim gets all ten checks', () async {
        final id = await newCase('cfr');
        final r = await readinessOf(id);
        expect(r['total'], 10);
        expect([for (final i in (r['items'] as List).cast<Map>()) i['id']],
            ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8', 'R9', 'R10']);
        expect(r['claim_type'], 'cfr');
        final byId = {for (final i in (r['items'] as List).cast<Map>()) i['id']: i['ok']};
        expect(byId['R10'], isTrue); // no dispute yet
        expect(byId['R1'], isFalse);
        expect(byId['R4'], isFalse); // no boundary mapped yet
        expect(byId['R8'], isFalse);
      });

      test('verified evidence moves R1; unverified, GPS and superseded items do not count', () async {
        final id = await newCase('ifr');
        final a = await addEvidence(id, general('7/12 extract'));
        final b = await addEvidence(id, general('Old well', rule: '13(1)(g)', kind: 'photo'));
        final gps = await addEvidence(id, {
          ...general('Bund corner', rule: '13(1)(c)', kind: 'gps_point'),
          'gps_lat': 19.9,
          'gps_lon': 73.2,
        });
        await submit(id);
        Future<bool> r1() async =>
            ((await readinessOf(id, token: gs))['items'] as List).cast<Map>().first['ok'] == true;
        expect(await r1(), isFalse);
        await h.call('POST', '/cases/$id/evidence/${a['id']}/verify', token: gs);
        expect(await r1(), isFalse); // one verified
        await h.call('POST', '/cases/$id/evidence/${gps['id']}/verify', token: gs);
        expect(await r1(), isFalse); // a verified GPS point never counts (BR-06)
        await h.call('POST', '/cases/$id/evidence/${b['id']}/verify', token: gs);
        expect(await r1(), isTrue); // two verified general items
        final r = await readinessOf(id, token: gs);
        expect(r['done'], 2); // R1 and R9 (acknowledged on filing)
      });

      test('R9 is met once the claim is filed', () async {
        final id = await newCase('ifr');
        Future<bool> r9() async => ((await readinessOf(id))['items'] as List)
            .cast<Map>()
            .firstWhere((i) => i['id'] == 'R9')['ok'] as bool;
        expect(await r9(), isFalse);
        await submit(id);
        expect(await r9(), isTrue);
      });

      test('R6 is met by three verified general items when there is no elder statement', () async {
        final id = await newCase('ifr');
        final ids = <String>[];
        for (final (i, rule) in ['13(1)(a)', '13(1)(b)', '13(1)(g)'].indexed) {
          ids.add((await addEvidence(id, general('Item $i', rule: rule)))['id'] as String);
        }
        await submit(id);
        Future<bool> r6() async => ((await readinessOf(id, token: gs))['items'] as List)
            .cast<Map>()
            .firstWhere((i) => i['id'] == 'R6')['ok'] as bool;
        for (final i in ids.take(2)) {
          await h.call('POST', '/cases/$id/evidence/$i/verify', token: gs);
        }
        expect(await r6(), isFalse);
        await h.call('POST', '/cases/$id/evidence/${ids.last}/verify', token: gs);
        expect(await r6(), isTrue);
      });

      test('visibility follows the case', () async {
        final id = await newCase('ifr');
        for (final t in [villager2, gs, sdo]) {
          expect((await h.fails('GET', '/cases/$id/readiness', token: t)).statusCode, 404);
        }
        await submit(id);
        expect((await readinessOf(id, token: gs))['case_id'], id);
        expect((await h.fails('GET', '/cases/$id/readiness', token: villager2)).statusCode, 404);
      });
    });

    group('media', () {
      test('upload, info and the bytes come back', () async {
        final bytes = Uint8List.fromList(List<int>.generate(300, (i) => i % 256));
        final m = await upload(villager,
            bytes: bytes,
            mime: 'Image/JPEG',
            name: 'well.jpg',
            fields: {
              'gps_lat': '19.9',
              'gps_lon': '73.2',
              'gps_accuracy_m': '4.5',
              'captured_at': '2026-10-14T06:00:00Z',
            });
        expect(m.keys.toSet(), {
          'id', 'sha256', 'mime', 'size_bytes', 'original_name', 'captured_at', 'gps_lat',
          'gps_lon', 'gps_accuracy_m', 'created_at',
        });
        expect(m['sha256'], hasLength(64));
        expect(m['mime'], 'image/jpeg');
        expect(m['size_bytes'], 300);
        expect(m['original_name'], 'well.jpg');
        expect(m['gps_lat'], 19.9);
        expect(m['gps_lon'], 73.2);
        expect(m['gps_accuracy_m'], 4.5);
        expect(DateTime.parse(m['captured_at'] as String), DateTime.utc(2026, 10, 14, 6));

        final info = await h.call('GET', '/media/${m['id']}', token: villager);
        expect(info, m);
        final got = await h.call('BYTES', '/media/${m['id']}/file', token: villager);
        expect(got, bytes);
        final viaGet = await h.call('GET', '/media/${m['id']}/file', token: villager);
        expect(viaGet, bytes);

        // the same bytes twice: same hash, own record each time
        final again = await upload(villager, bytes: bytes, mime: 'image/jpeg');
        expect(again['sha256'], m['sha256']);
        expect(again['id'], isNot(m['id']));
        expect(again['original_name'], '712.pdf');
        expect(again['gps_lat'], isNull);
        expect(again['captured_at'], isNull);
      });

      test('unsupported type 415, empty file 422, too big 413, bad fields 422', () async {
        Future<ApiException> bad(Map<String, dynamic> body) =>
            h.fails('UPLOAD', '/media', token: villager, body: body);
        final exe = await bad({
          'file_base64': base64Encode([77, 90]),
          'filename': 'x.exe',
          'mime': 'application/x-msdownload',
          'fields': <String, String>{},
        });
        expect((exe.statusCode, exe.error, exe.messageKey, exe.details!['mime']),
            (415, 'UNSUPPORTED_MEDIA_TYPE', 'media.unsupported_type', 'application/x-msdownload'));
        final empty = await bad({'file_base64': '', 'filename': 'e.pdf', 'mime': 'application/pdf'});
        expect((empty.statusCode, empty.error, empty.messageKey), (422, 'EMPTY_FILE', 'media.empty'));
        final big = await bad({
          'file_base64': base64Encode(Uint8List(20 * 1024 * 1024 + 1)),
          'filename': 'big.pdf',
          'mime': 'application/pdf',
        });
        expect((big.statusCode, big.error, big.details!['max_mb']), (413, 'FILE_TOO_LARGE', 20));
        final noFile = await bad({'filename': 'e.pdf', 'mime': 'application/pdf'});
        expect(noFile.statusCode, 422);
        expect(noFile.error, 'VALIDATION_ERROR');
        for (final fields in [
          {'gps_lat': '95'},
          {'gps_lon': 'east'},
          {'gps_accuracy_m': '-2'},
          {'captured_at': 'yesterday'},
        ]) {
          final e = await bad({
            'file_base64': base64Encode([1, 2, 3]),
            'filename': 'a.pdf',
            'mime': 'application/pdf',
            'fields': fields,
          });
          expect(e.statusCode, 422, reason: '$fields');
        }
      });

      test('only the uploader, or someone who may see a case that uses it, reads a file', () async {
        final m = await upload(villager);
        for (final t in [villager2, gs, sdo]) {
          final e = await h.fails('GET', '/media/${m['id']}', token: t);
          expect((e.statusCode, e.error, e.messageKey), (404, 'MEDIA_NOT_FOUND', 'media.not_found'));
          expect((await h.fails('BYTES', '/media/${m['id']}/file', token: t)).statusCode, 404);
        }
        final unknown = await h.fails('GET', '/media/01900000-0000-7000-8000-000000000001', token: villager);
        expect(unknown.statusCode, 404);

        // attached to a draft: the Gram Sabha still cannot see the case, so not the file
        final id = await newCase('ifr');
        await addEvidence(id, {...general('Scan'), 'media_id': m['id']});
        expect((await h.fails('GET', '/media/${m['id']}', token: gs)).statusCode, 404);
        // filed: the Gram Sabha may read it
        await submit(id);
        expect((await h.call('GET', '/media/${m['id']}', token: gs) as Map)['id'], m['id']);
        final bytes = await h.call('BYTES', '/media/${m['id']}/file', token: gs);
        expect(utf8.decode(bytes as List<int>), startsWith('%PDF-1.4'));
        // still not another villager, nor the SDO (the case is not with them)
        expect((await h.fails('GET', '/media/${m['id']}', token: villager2)).statusCode, 404);
        expect((await h.fails('GET', '/media/${m['id']}', token: sdo)).statusCode, 404);
      });

      test('the signed sheet of an elder statement is served the same way', () async {
        final id = await newCase('ifr');
        final scan = await upload(villager);
        // an elder who is not on the roster is refused, so attach the scan to a plain item
        await addEvidence(id, {...general('Signed sheet'), 'signed_scan_media_id': scan['id']});
        await submit(id);
        expect((await h.call('GET', '/media/${scan['id']}/file', token: gs)), isA<List<int>>());
      });
    });

    group('elders, claimants and the ledger', () {
      Future<List<Map<String, dynamic>>> members() async =>
          ((await h.call('GET', '/villages/$village/members', token: gs)) as List)
              .cast<Map<String, dynamic>>();

      test('an elder statement from a roster member is accepted and needs the signed sheet for R6',
          () async {
        final id = await newCase('cfr');
        final elder = (await members()).first;
        final scan = await upload(villager);
        final e = await addEvidence(id, {
          ...general('Statement of the elder', rule: '13(1)(i)', kind: 'elder_statement'),
          'elder_member_id': elder['id'],
          'transcript': ' We have used this forest since our grandfathers time ',
          'signed_scan_media_id': scan['id'],
        });
        expect(e['kind'], 'elder_statement');
        expect(e['elder_member_id'], elder['id']);
        expect(e['transcript'], 'We have used this forest since our grandfathers time');
        expect(e['signed_scan_media_id'], scan['id']);
        expect(e['is_substitutable'], isTrue);
        await submit(id);
        Future<bool> r6() async => ((await readinessOf(id, token: gs))['items'] as List)
            .cast<Map>()
            .firstWhere((i) => i['id'] == 'R6')['ok'] as bool;
        expect(await r6(), isFalse); // not verified yet
        await h.call('POST', '/cases/$id/evidence/${e['id']}/verify', token: gs);
        expect(await r6(), isTrue); // verified, with its signed sheet
      });

      test('evidence and verifications join the Gram Sabha hash chain, which stays intact', () async {
        final id = await newCase('ifr');
        final item = await addEvidence(id, general('7/12 extract'));
        await submit(id);
        await h.call('POST', '/cases/$id/evidence/${item['id']}/verify', token: gs);
        final r = await h.call('GET', '/villages/$village/ledger/verify', token: gs) as Map;
        expect(r['ok'], isTrue, reason: '$r');
        // one evidence, one submit event, one verification
        expect(r['length'], 3);
      });

      test('a claimant may not be the elder, and may not verify their own case (Rule 3(3))',
          () async {
        final id = await newCase('cfr');
        final all = await members();
        final claimant = all[0];
        final put = await (() async {
          try {
            return await h.call('PUT', '/cases/$id/claimants',
                token: villager, body: {'member_ids': [claimant['id']]});
          } on ApiException catch (e) {
            if (e.messageKey == 'demo.not_available') return null;
            rethrow;
          }
        })();
        if (put == null) {
          markTestSkipped('the claimants route of the forms slice is not registered yet');
          return;
        }
        final e = await h.fails('POST', '/cases/$id/evidence',
            token: villager,
            body: {
              ...general('Statement', rule: '13(1)(i)', kind: 'elder_statement'),
              'elder_member_id': claimant['id'],
              'transcript': 'We used this forest',
            });
        expect((e.statusCode, e.error, e.rule, e.messageKey),
            (409, 'ELDER_IS_CLAIMANT', 'Rule 13(1)(i)', 'evidence.elder_is_claimant'));
        expect(e.details!['elder_member_id'], claimant['id']);
      });
    });

    group('acknowledgement (Rule 11(3))', () {
      test('not yet filed is a 409; filing issues OZH/<year>/0001 once', () async {
        final id = await newCase('ifr');
        final e = await h.fails('GET', '/cases/$id/acknowledgement', token: villager);
        expect((e.statusCode, e.error, e.messageKey), (409, 'NOT_YET_FILED', 'acknowledgement.not_yet_filed'));

        await addEvidence(id, general('7/12 extract'));
        await addEvidence(id, general('Old well', rule: '13(1)(g)', kind: 'photo'));
        await submit(id);
        final ack = Map<String, dynamic>.from(
            await h.call('GET', '/cases/$id/acknowledgement', token: villager) as Map);
        expect(ack.keys.toSet(), {
          'case_id', 'serial', 'acknowledged_on', 'form', 'claim_type', 'claimant_label',
          'village', 'gram_panchayat', 'filed_within_window', 'documents_received',
        });
        expect(ack['case_id'], id);
        expect(ack['serial'], 'OZH/2026/0001');
        expect(ack['acknowledged_on'], '2026-10-14');
        expect(ack['form'], 'A');
        expect(ack['claim_type'], 'ifr');
        expect(ack['village'], 'ओझर (Ozhar)');
        expect(ack['gram_panchayat'], 'Ozhar');
        expect(ack['filed_within_window'], isNull); // no call for claims recorded
        expect(ack['documents_received'], ['13(1)(a): 7/12 extract', '13(1)(g): Old well']);
        expect(ack['claimant_label'], isA<String>());

        // the Gram Sabha sees it too; others do not
        expect((await h.call('GET', '/cases/$id/acknowledgement', token: gs) as Map)['serial'], 'OZH/2026/0001');
        expect((await h.fails('GET', '/cases/$id/acknowledgement', token: villager2)).statusCode, 404);
      });

      test('serials count up per Gram Sabha register; a returned and refiled claim keeps its number',
          () async {
        final a = await newCase('ifr');
        final b = await newCase('ifr', token: villager2);
        await submit(a);
        await submit(b, token: villager2);
        String serial(Object? m) => (m as Map)['serial'] as String;
        expect(serial(await h.call('GET', '/cases/$a/acknowledgement', token: villager)), 'OZH/2026/0001');
        expect(serial(await h.call('GET', '/cases/$b/acknowledgement', token: villager2)), 'OZH/2026/0002');

        await h.call('POST', '/cases/$a/return', token: gs, body: {'remarks': 'Fix the survey number'});
        h.advance(const Duration(days: 3));
        await submit(a);
        final again = await h.call('GET', '/cases/$a/acknowledgement', token: villager);
        expect(serial(again), 'OZH/2026/0001');
        expect((again as Map)['acknowledged_on'], '2026-10-14');
        // a Form C claim opened by the villager takes the next number
        final c = await newCase('cfr');
        await submit(c);
        expect(serial(await h.call('GET', '/cases/$c/acknowledgement', token: villager)), 'OZH/2026/0003');
        expect((await h.call('GET', '/cases/$c/acknowledgement', token: villager) as Map)['form'], 'C');
      });

      test('the evidence list of the receipt stops at the filing day', () async {
        final id = await newCase('ifr');
        await addEvidence(id, general('Before filing'));
        await submit(id);
        h.advance(const Duration(days: 2));
        await addEvidence(id, general('Added by the Gram Sabha later', rule: '13(1)(g)'), token: gs);
        final ack = await h.call('GET', '/cases/$id/acknowledgement', token: gs) as Map;
        expect(ack['documents_received'], ['13(1)(a): Before filing']);
      });
    });

    group('documents', () {
      test('G4 is the printable acknowledgement; it is refused until the claim is filed', () async {
        final id = await newCase('ifr');
        final early = await h.fails('GET', '/cases/$id/documents/g4', token: villager);
        expect((early.statusCode, early.error), (409, 'NOT_YET_FILED'));
        await addEvidence(id, general('7/12 <extract> & more'));
        await submit(id);
        final html = await h.call('GET', '/cases/$id/documents/G4?lang=mr', token: villager);
        expect(html, isA<String>());
        final page = html as String;
        expect(page, startsWith('<!doctype html>'));
        expect(page, contains('<html lang="mr">'));
        expect(page, contains('दावा प्राप्त झाल्याची पोच / Acknowledgement of claim received'));
        expect(page, contains('OZH/2026/0001'));
        expect(page, contains('Received within the call for claims: No call recorded'));
        expect(page, contains('13(1)(a): 7/12 &lt;extract&gt; &amp; more')); // escaped
        expect(page, contains('Case $id'));
        expect(page, contains('body SHA-256'));
        expect(page, contains('Not a government document'));
        final en = await h.call('GET', '/cases/$id/documents/g4', token: gs) as String;
        expect(en, contains('<html lang="en">'));
        expect(en, isNot(contains('दावा प्राप्त झाल्याची पोच / ')));
      });

      test('unknown code 404, bad language 422, missing meeting or dispute 422, nothing recorded 404',
          () async {
        final id = await newCase('cfr');
        final unknown = await h.fails('GET', '/cases/$id/documents/g99', token: villager);
        expect((unknown.statusCode, unknown.error, unknown.messageKey),
            (404, 'UNKNOWN_DOCUMENT', 'document.unknown'));
        expect(unknown.details!['available'], ['g4', 'g8', 'g9', 'g10', 'g12', 'g13', 'g17']);
        expect((await h.fails('GET', '/cases/$id/documents/g4?lang=fr', token: villager)).statusCode, 422);
        final noMeeting = await h.fails('GET', '/cases/$id/documents/g12', token: villager);
        expect((noMeeting.statusCode, noMeeting.error), (422, 'MEETING_REQUIRED'));
        final noDispute = await h.fails('GET', '/cases/$id/documents/g17', token: villager);
        expect((noDispute.statusCode, noDispute.error), (422, 'DISPUTE_REQUIRED'));
        final noRes = await h.fails('GET', '/cases/$id/documents/g13', token: villager);
        expect((noRes.statusCode, noRes.error), (404, 'NO_RESOLUTION'));
        final noBoundary = await h.fails('GET', '/cases/$id/documents/g9', token: villager);
        expect((noBoundary.statusCode, noBoundary.error), (404, 'NO_BOUNDARY'));
        final g10 = await h.fails('GET', '/cases/$id/documents/g10', token: villager);
        expect((g10.statusCode, g10.error), (404, 'NO_BOUNDARY'));
        final meeting = await h.fails(
            'GET', '/cases/$id/documents/g12?meeting_id=01900000-0000-7000-8000-000000000001',
            token: villager);
        expect((meeting.statusCode, meeting.error), (404, 'MEETING_NOT_FOUND'));
        final dispute = await h.fails(
            'GET', '/cases/$id/documents/g17?dispute_id=01900000-0000-7000-8000-000000000001',
            token: villager);
        expect((dispute.statusCode, dispute.error), (404, 'DISPUTE_NOT_FOUND'));
        // G8 with no visit recorded is a page that says so
        final g8 = await h.call('GET', '/cases/$id/documents/g8', token: villager) as String;
        expect(g8, contains('No visit recorded yet.'));
      });

      test('boundary documents belong to a Form C case', () async {
        final id = await newCase('ifr');
        final e = await h.fails('GET', '/cases/$id/documents/g9', token: villager);
        expect((e.statusCode, e.error, e.messageKey), (409, 'NOT_A_FORM_C_CASE', 'case.wrong_form'));
      });

      test('visibility follows the case', () async {
        final id = await newCase('ifr');
        for (final t in [villager2, gs, sdo]) {
          expect((await h.fails('GET', '/cases/$id/documents/g4', token: t)).statusCode, 404);
        }
        expect((await h.fails('GET', '/cases/$id/documents/g99', token: villager2)).statusCode, 404,
            reason: 'unknown code answers before the case is looked up');
      });

      test('a letter that does not exist is 404', () async {
        final e = await h.fails('GET', '/letters/01900000-0000-7000-8000-000000000001/document', token: gs);
        expect((e.statusCode, e.error, e.messageKey), (404, 'LETTER_NOT_FOUND', 'letter.not_found'));
      });
    });
  });
}
