import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';
import 'package:vanmitra_ai/demo/core/demo_core.dart';
import 'package:vanmitra_ai/demo/demo_backend.dart';
import 'package:vanmitra_ai/demo/demo_mode.dart';
import 'package:vanmitra_ai/demo/gramsabha/demo_gramsabha.dart';
import 'package:vanmitra_ai/demo/gramsabha/demo_ledger.dart';
import 'package:vanmitra_ai/demo/gramsabha/demo_quorum.dart';

import 'demo_support.dart';

const String _village = DemoAccounts.villageId;
const String _gsPhone = '9000000003';
const String _villagerPhone = '9000000001';

/// Like [DemoHarness], but keeps the in-memory data so a test can put in rows that other parts of
/// the demo own (boundary, letters, uploads) and tamper with stored records.
class _Env {
  _Env() {
    DemoMode.idForTest = 'all';
    backend = DemoBackend(
      storage: storage,
      loadAsset: (path) => File(path).readAsString(),
      clock: () => now,
    );
  }

  final MemoryDemoStorage storage = MemoryDemoStorage();
  DateTime now = DateTime.utc(2026, 10, 14, 6, 30);
  late final DemoBackend backend;

  Map<String, dynamic> get data => storage.read();

  List<Map<String, dynamic>> table(String name) =>
      (data.putIfAbsent(name, () => <dynamic>[]) as List).cast<Map<String, dynamic>>();

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
}

String _userId(_Env e, String phone) =>
    e.table('app_user').firstWhere((u) => u['phone'] == phone)['id'] as String;

void main() {
  tearDown(() => DemoMode.idForTest = null);

  // ── domain/quorum.py: tests/unit/test_quorum.py ─────────────────────────────

  group('quorum (Rule 4(2))', () {
    QuorumResult base({
      int registered = 100,
      int present = 50,
      int women = 17,
      int total = 10,
      int there = 5,
    }) =>
        quorum(
          registered: registered,
          present: present,
          womenPresent: women,
          claimantsTotal: total,
          claimantsPresent: there,
        );

    test('all three pass', () {
      final q = base();
      expect(q.passed, isTrue);
      expect([q.requiredPresent, q.requiredWomen, q.requiredClaimants], [50, 17, 5]);
      expect(q.failures, isEmpty);
    });

    test('each test fails alone at the boundary', () {
      var q = base(present: 49, women: 17);
      expect(q.passed, isFalse);
      expect(q.failures, ['quorum.t1_present']);
      q = base(women: 16);
      expect(q.failures, ['quorum.t2_women']);
      q = base(there: 4);
      expect(q.failures, ['quorum.t3_claimants']);
    });

    test('rounding goes up', () {
      final q = quorum(
          registered: 101, present: 51, womenPresent: 17, claimantsTotal: 3, claimantsPresent: 2);
      expect(q.requiredPresent, 51);
      expect(q.requiredClaimants, 2);
      expect(q.passed, isTrue);
    });

    test('no claimants means the third test is met', () {
      expect(quorum(registered: 10, present: 5, womenPresent: 2).t3, isTrue);
    });

    test('an empty meeting never passes', () {
      expect(quorum(registered: 0, present: 0, womenPresent: 0).passed, isFalse);
      expect(quorum(registered: 10, present: 0, womenPresent: 0).passed, isFalse);
    });

    test('the proof is plain data with the backend keys', () {
      final proof = quorum(registered: 10, present: 5, womenPresent: 2).proof();
      expect(proof['passed'], isTrue);
      expect(proof['registered'], 10);
      expect(proof.keys.toList(), [
        'registered',
        'present',
        'women_present',
        'claimants_total',
        'claimants_present',
        'required_present',
        'required_women',
        'required_claimants',
        't1',
        't2',
        't3',
        'passed',
        'failures',
      ]);
    });
  });

  // ── services/ledger.py ──────────────────────────────────────────────────────

  group('ledger hash chain', () {
    late DemoDb db;
    late String gs;

    Map<String, dynamic> record(String text) =>
        db.add('workflow_event', {'case_id': 'c', 'action': 'submit', 'remarks': text});

    setUp(() {
      db = DemoDb({});
      gs = (db.add('gram_sabha', {
        'village_id': 'v',
        'chain_head_hash': null,
        'chain_length': 0,
      }))['id'] as String;
    });

    test('canonical payload sorts keys and has no spaces; sha256 is the real one', () {
      expect(
          DemoLedger.canonicalPayload({
            'b': 1,
            'a': 'x',
            'c': [true, null]
          }),
          '{"a":"x","b":1,"c":[true,null]}');
      expect(DemoLedger.canonicalPayload({'n': 'मराठी'}), '{"n":"मराठी"}');
      expect(DemoLedger.canonicalPayload({'n': 'é'}, asciiOnly: true), '{"n":"\\u00e9"}');
      expect(DemoLedger.linkHash('', ''),
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('an empty chain is intact and at genesis', () {
      final r = DemoLedger.verify(db, gs);
      expect(r.ok, isTrue);
      expect(r.length, 0);
      expect(r.head, DemoLedger.genesis);
    });

    test('appending extends the chain and verifies', () {
      final a = record('one');
      final e1 = DemoLedger.append(db, gs, 'workflow_event', a);
      expect(e1['seq'], 1);
      expect(e1['prev_hash'], DemoLedger.genesis);
      final b = record('two');
      final e2 = DemoLedger.append(db, gs, 'workflow_event', b);
      expect(e2['seq'], 2);
      expect(e2['prev_hash'], e1['record_hash']);
      final gsRow = db.byId('gram_sabha', gs)!;
      expect(gsRow['chain_length'], 2);
      expect(gsRow['chain_head_hash'], e2['record_hash']);
      final r = DemoLedger.verify(db, gs);
      expect(r.ok, isTrue);
      expect(r.length, 2);
      expect(r.head, e2['record_hash']);
      expect(r.toJson().keys,
          containsAll(['ok', 'length', 'head', 'broken_at_seq', 'broken_entity', 'reason']));
    });

    test('an altered record is found, with its place in the chain', () {
      final a = record('one');
      DemoLedger.append(db, gs, 'workflow_event', a);
      final b = record('two');
      DemoLedger.append(db, gs, 'workflow_event', b);
      DemoLedger.append(db, gs, 'workflow_event', record('three'));
      b['remarks'] = 'changed';
      final r = DemoLedger.verify(db, gs);
      expect(r.ok, isFalse);
      expect(r.brokenAtSeq, 2);
      expect(r.brokenEntity, 'workflow_event');
      expect(r.reason, 'record altered');
    });

    test('a missing record, a broken link and a wrong head are found', () {
      final a = record('one');
      DemoLedger.append(db, gs, 'workflow_event', a);
      final b = record('two');
      DemoLedger.append(db, gs, 'workflow_event', b);

      db.table('workflow_event').remove(b);
      var r = DemoLedger.verify(db, gs);
      expect((r.ok, r.brokenAtSeq, r.reason), (false, 2, 'record missing'));
      db.table('workflow_event').add(b);

      final entries = db.table('ledger_entry');
      entries.last['prev_hash'] = 'f' * 64;
      r = DemoLedger.verify(db, gs);
      expect((r.ok, r.brokenAtSeq, r.reason), (false, 2, 'chain link broken'));
      entries.last['prev_hash'] = entries.first['record_hash'];

      db.byId('gram_sabha', gs)!['chain_head_hash'] = '0' * 64;
      r = DemoLedger.verify(db, gs);
      expect((r.ok, r.brokenAtSeq, r.reason), (false, null, 'chain head mismatch'));
    });

    test('each Gram Sabha has its own chain', () {
      final other =
          db.add('gram_sabha', {'village_id': 'w', 'chain_head_hash': null, 'chain_length': 0});
      DemoLedger.append(db, gs, 'workflow_event', record('one'));
      DemoLedger.append(db, other['id'] as String, 'workflow_event', record('two'));
      expect(DemoLedger.verify(db, gs).length, 1);
      expect(DemoLedger.verify(db, other['id'] as String).length, 1);
    });

    test('entityOf recognises the chained records by their fields', () {
      expect(DemoLedger.entityOf({'action': 'submit', 'to_state': 'gs_review'}), 'workflow_event');
      expect(DemoLedger.entityOf({'quorum_proof': {}}), 'resolution');
      expect(DemoLedger.entityOf({'attempt_no': 1}), 'verification_proceeding');
      expect(DemoLedger.entityOf({'rule_ref': 'x', 'kind': 'y'}), 'evidence');
      expect(DemoLedger.entityOf({'evidence_id': 'e', 'verified_by_user_id': 'u'}),
          'evidence_verification');
    });
  });

  // ── api/v1/members.py ───────────────────────────────────────────────────────

  group('members', () {
    test('everyone in the village can read the roster, sorted by name', () async {
      final h = DemoHarness();
      addTearDown(h.dispose);
      final villager = await h.login(_villagerPhone);
      final list = await h.call('GET', '/villages/$_village/members', token: villager) as List;
      expect(list.map((m) => m['name']), [for (var i = 1; i <= 5; i++) 'Demo Member $i']);
      expect(list.first.keys, containsAll(['id', 'name', 'gender', 'category', 'active']));
      final noToken = await h.fails('GET', '/villages/$_village/members');
      expect(noToken.statusCode, 401);
    });

    test('only the Gram Sabha edits the roster; members are deactivated, not deleted', () async {
      final h = DemoHarness();
      addTearDown(h.dispose);
      final gs = await h.login(_gsPhone);
      final villager = await h.login(_villagerPhone);
      final body = {'name': ' Asha ', 'gender': 'female', 'category': 'st'};

      final denied =
          await h.fails('POST', '/villages/$_village/members', token: villager, body: body);
      expect(denied.statusCode, 403);
      expect(denied.error, 'FORBIDDEN');

      final added =
          await h.call('POST', '/villages/$_village/members', token: gs, body: body) as Map;
      expect(added['name'], 'Asha');
      expect(added['active'], isTrue);
      expect(((await h.call('GET', '/villages/$_village/members', token: gs)) as List).length, 6);

      final bad = await h.fails('POST', '/villages/$_village/members',
          token: gs, body: {'name': '', 'gender': 'x'});
      expect(bad.statusCode, 422);
      expect(bad.error, 'VALIDATION_ERROR');
      final errors = (bad.details!['errors'] as List).cast<Map>();
      expect(
          errors.map((e) => (e['loc'] as List).last), containsAll(['name', 'gender', 'category']));

      final id = added['id'] as String;
      expect(
          (await h.fails('PATCH', '/members/$id', token: villager, body: {'active': false}))
              .statusCode,
          403);
      final off = await h.call('PATCH', '/members/$id', token: gs, body: {'active': false}) as Map;
      expect(off['active'], isFalse);
      expect(((await h.call('GET', '/villages/$_village/members', token: gs)) as List).length, 5);
      final all = await h.call('GET', '/villages/$_village/members?include_inactive=true',
          token: gs) as List;
      expect(all.length, 6);

      final renamed =
          await h.call('PATCH', '/members/$id', token: gs, body: {'name': 'Asha P', 'gender': null})
              as Map;
      expect((renamed['name'], renamed['gender']), ('Asha P', 'female'));
      final missing = await h.fails('PATCH', '/members/00000000-0000-4000-8000-000000000999',
          token: gs, body: {'active': true});
      expect((missing.statusCode, missing.error), (404, 'MEMBER_NOT_FOUND'));
    });
  });

  // ── meetings, attendance, quorum, resolutions on a Form A claim ─────────────

  group('meeting, attendance, quorum, resolution', () {
    test('the whole Gram Sabha path on an individual (Form A) claim', () async {
      final h = DemoHarness();
      addTearDown(h.dispose);
      final gs = await h.login(_gsPhone);
      final villager = await h.login(_villagerPhone);
      const meetings = '/villages/$_village/meetings';
      final held = {'held_on': '2026-10-14', 'place': 'Gram Panchayat', 'agenda': 'Forest claims'};

      // only the Gram Sabha holds meetings; every village role reads them
      expect((await h.fails('POST', meetings, token: villager, body: held)).statusCode, 403);
      expect((await h.fails('POST', meetings, body: held)).statusCode, 401);
      final invalid = await h.fails('POST', meetings, token: gs, body: {'held_on': '14/10/2026'});
      expect(invalid.statusCode, 422);
      expect((invalid.details!['errors'] as List).length, 3); // date, place, agenda
      final late =
          await h.fails('POST', meetings, token: gs, body: {...held, 'notice_on': '2026-10-15'});
      expect((late.statusCode, late.error), (422, 'NOTICE_AFTER_MEETING'));

      final m = await h
          .call('POST', meetings, token: gs, body: {...held, 'notice_on': '2026-10-07'}) as Map;
      expect(m['registered_count'], 5);
      expect(m['attendance_recorded'], isFalse);
      expect((m['present_count'], m['women_present'], m['resolutions']), (0, 0, 0));
      final mid = m['id'] as String;
      expect(await h.call('GET', meetings, token: villager), hasLength(1));
      expect((await h.call('GET', '/meetings/$mid', token: villager) as Map)['agenda'],
          'Forest claims');

      // attendance: members 1, 2 and 3 (two women) are present
      final roster =
          (await h.call('GET', '/villages/$_village/members', token: gs) as List).cast<Map>();
      final ids = [for (final r in roster) r['id'] as String];
      final put = '/meetings/$mid/attendance';
      expect(
          (await h.fails('PUT', put, token: villager, body: {'present_member_ids': ids}))
              .statusCode,
          403);
      final stranger = await h.fails('PUT', put, token: gs, body: {
        'present_member_ids': ['00000000-0000-4000-8000-000000000999']
      });
      expect((stranger.statusCode, stranger.error), (422, 'MEMBER_NOT_IN_ROSTER'));
      expect(
          (await h.fails('PUT', put, token: gs, body: {
            'present_member_ids': ['nope']
          }))
              .statusCode,
          422);
      final att = await h
          .call('PUT', put, token: gs, body: {'present_member_ids': ids.sublist(0, 3)}) as Map;
      expect(
          (att['present_count'], att['women_present'], att['attendance_recorded']), (3, 2, true));
      final q = await h.call('GET', '/meetings/$mid/quorum', token: villager) as Map;
      expect(q['passed'], isTrue);
      expect((q['registered'], q['required_present'], q['required_women']), (5, 3, 1));
      expect(q['failures'], isEmpty);

      // a Form A claim reaches the Gram Sabha
      final c = await h.call('POST', '/villages/$_village/cases',
          token: villager, body: {'claim_type': 'ifr'}) as Map;
      final cid = c['id'] as String;
      final res = '/meetings/$mid/resolutions';
      final decision = {
        'case_id': cid,
        'decision_text': 'The claim is recommended',
        'votes_for': 3,
        'votes_against': 0,
      };
      // still a draft: the Gram Sabha cannot even see it
      expect((await h.fails('POST', res, token: gs, body: decision)).statusCode, 404);
      await h.call('POST', '/cases/$cid/submit', token: villager);

      expect((await h.fails('POST', res, token: villager, body: decision)).statusCode, 403);
      final many = await h.fails('POST', res, token: gs, body: {...decision, 'votes_for': 4});
      expect((many.statusCode, many.error), (422, 'MORE_VOTES_THAN_PRESENT'));
      final lost = await h
          .fails('POST', res, token: gs, body: {...decision, 'votes_for': 1, 'votes_against': 2});
      expect((lost.statusCode, lost.error, lost.rule), (409, 'MOTION_NOT_CARRIED', 'Rule 4(2)'));
      final tied = await h
          .fails('POST', res, token: gs, body: {...decision, 'votes_for': 1, 'votes_against': 1});
      expect(tied.error, 'MOTION_NOT_CARRIED');
      final negative = await h.fails('POST', res, token: gs, body: {...decision, 'votes_for': -1});
      expect(negative.statusCode, 422);
      final nowhere = await h.fails('POST', res,
          token: gs, body: {...decision, 'case_id': '00000000-0000-4000-8000-000000000999'});
      expect((nowhere.statusCode, nowhere.error), (404, 'CASE_NOT_FOUND'));

      // quorum fails when too few are there
      final few = await h.call('PUT', put, token: gs, body: {
        'present_member_ids': [ids[1]]
      }) as Map;
      expect(few['present_count'], 1);
      final failed = await h
          .fails('POST', res, token: gs, body: {...decision, 'votes_for': 1, 'votes_against': 0});
      expect((failed.statusCode, failed.error, failed.rule), (409, 'QUORUM_FAILED', 'Rule 4(2)'));
      expect(failed.details!['failures'], containsAll(['quorum.t1_present', 'quorum.t2_women']));
      expect(failed.details!['registered'], 5);
      await h.call('PUT', put, token: gs, body: {'present_member_ids': ids.sublist(0, 3)});

      final r = await h.call('POST', res, token: gs, body: decision) as Map;
      expect(r['number'], '1/2026');
      expect(r['boundary_id'], isNull);
      expect((r['quorum_proof'] as Map)['passed'], isTrue);
      expect((r['votes_for'], r['votes_against']), (3, 0));
      for (final k in [
        'id',
        'meeting_id',
        'case_id',
        'decision_text',
        'signed_scan_media_id',
        'created_at'
      ]) {
        expect(r.containsKey(k), isTrue, reason: k);
      }

      // the register is locked once a resolution is recorded
      final locked = await h.fails('PUT', put, token: gs, body: {'present_member_ids': ids});
      expect((locked.statusCode, locked.error), (409, 'ATTENDANCE_LOCKED'));
      expect((await h.call('GET', '/meetings/$mid', token: gs) as Map)['resolutions'], 1);
      final listed = await h.call('GET', '/cases/$cid/resolutions', token: villager) as List;
      expect(listed, hasLength(1));
      expect((listed.single as Map)['number'], '1/2026');

      // a second resolution at another meeting supersedes the first; numbers go on
      final m2 = await h.call('POST', meetings, token: gs, body: held) as Map;
      await h.call('PUT', '/meetings/${m2['id']}/attendance',
          token: gs, body: {'present_member_ids': ids.sublist(0, 4)});
      final r2 = await h.call('POST', '/meetings/${m2['id']}/resolutions',
          token: gs, body: decision) as Map;
      expect(r2['number'], '2/2026');
      expect(await h.call('GET', '/cases/$cid/resolutions', token: gs), hasLength(2));
      expect(await h.call('GET', meetings, token: gs), hasLength(2));

      // Form A and B need nothing before approval: the claim goes to the SDO
      final check = await h.call('GET', '/cases/$cid/approval-check', token: gs) as Map;
      expect((check['case_id'], check['ready']), (cid, true));
      expect(check['items'], isEmpty);
      final approved = await h.call('POST', '/cases/$cid/approve', token: gs) as Map;
      expect(approved['state'], 'sdo_review');

      // every action is in the village's tamper-evident chain
      final chain =
          await h.call('GET', '/villages/$_village/ledger/verify', token: villager) as Map;
      expect(chain['ok'], isTrue);
      expect(chain['length'], 4); // submit, resolution, resolution, approve
      expect(chain['head'], hasLength(64));
      expect(chain['broken_at_seq'], isNull);
    });

    test('quorum with a claim counts the claimants who are present (test 3)', () async {
      final e = _Env();
      addTearDown(() => DemoMode.idForTest = null);
      final gs = await e.login(_gsPhone);
      final villager = await e.login(_villagerPhone);
      final c = await e.call('POST', '/villages/$_village/cases',
          token: villager, body: {'claim_type': 'cr'}) as Map;
      final cid = c['id'] as String;
      final members = e.table('gs_member');
      for (final m in members.take(2)) {
        e.table('case_claimant').add({'case_id': cid, 'gs_member_id': m['id']});
      }
      final m = await e.call('POST', '/villages/$_village/meetings',
          token: gs, body: {'held_on': '2026-10-14', 'place': 'Hall', 'agenda': 'Claim'}) as Map;
      final ids = [for (final x in members) x['id'] as String];
      // the two claimants (members 1 and 2) are away: 3 present, 2 women, but 0 of 2 claimants
      await e.call('PUT', '/meetings/${m['id']}/attendance',
          token: gs, body: {'present_member_ids': ids.sublist(2)});
      final q = await e.call('GET', '/meetings/${m['id']}/quorum?case_id=$cid', token: gs) as Map;
      expect((q['claimants_total'], q['claimants_present'], q['required_claimants']), (2, 0, 1));
      expect((q['t1'], q['t2'], q['t3'], q['passed']), (true, true, false, false));
      expect(q['failures'], ['quorum.t3_claimants']);
      expect(
          (await e.call('GET', '/meetings/${m['id']}/quorum', token: gs) as Map)['passed'], isTrue);

      await e.call('POST', '/cases/$cid/submit', token: villager);
      final denied = await e.fails('POST', '/meetings/${m['id']}/resolutions', token: gs, body: {
        'case_id': cid,
        'decision_text': 'Approved',
        'votes_for': 3,
        'votes_against': 0,
      });
      expect(denied.error, 'QUORUM_FAILED');
      expect(denied.details!['failures'], ['quorum.t3_claimants']);

      // one claimant comes: 1 of 2 is enough
      await e.call('PUT', '/meetings/${m['id']}/attendance', token: gs, body: {
        'present_member_ids': [ids[0], ids[2], ids[4]]
      });
      final ok = await e.call('POST', '/meetings/${m['id']}/resolutions', token: gs, body: {
        'case_id': cid,
        'decision_text': 'Approved',
        'votes_for': 2,
        'votes_against': 1,
      }) as Map;
      expect((ok['quorum_proof'] as Map)['claimants_present'], 1);
    });
  });

  // ── a community forest (Form C) claim: the approval check and the ledger ────

  group('Form C approval check', () {
    const g7 = '00000000-0000-4000-8000-0000000000a7';
    const ownSheet = '00000000-0000-4000-8000-0000000000f2';
    const otherSheet = '00000000-0000-4000-8000-0000000000f1';
    late _Env e;
    late String gs;
    late String villager;
    late String cid;
    late String mid;
    late List<String> ids;
    late Map<String, dynamic> boundary;

    Map<String, dynamic> resolutionBody({int votesFor = 3, int votesAgainst = 0}) => {
          'case_id': cid,
          'decision_text': 'The claim and the map are approved',
          'votes_for': votesFor,
          'votes_against': votesAgainst,
        };

    Map<String, dynamic> visitBody([Map<String, dynamic> extra = const {}]) => {
          'visit_on': '2026-10-10',
          'observations': 'Walked the boundary',
          'presence': [
            {'name': 'RFO Patil', 'designation': 'RFO', 'department': 'forest'},
          ],
          ...extra,
        };

    Future<Map> check([String? token]) async =>
        await e.call('GET', '/cases/$cid/approval-check', token: token ?? gs) as Map;

    Map<String, dynamic> itemsOk(Map c) => {
          for (final i in (c['items'] as List).cast<Map>()) i['id'] as String: i['ok'],
        };

    setUp(() async {
      e = _Env();
      gs = await e.login(_gsPhone);
      villager = await e.login(_villagerPhone);
      final c = await e.call('POST', '/villages/$_village/cases',
          token: villager, body: {'claim_type': 'cfr'}) as Map;
      cid = c['id'] as String;
      await e.call('POST', '/cases/$cid/submit', token: villager);
      final m = await e.call('POST', '/villages/$_village/meetings',
          token: gs, body: {'held_on': '2026-10-14', 'place': 'Hall', 'agenda': 'CFR'}) as Map;
      mid = m['id'] as String;
      ids = [for (final x in e.table('gs_member')) x['id'] as String];
      await e.call('PUT', '/meetings/$mid/attendance',
          token: gs, body: {'present_member_ids': ids.sublist(0, 3)});
      // rows that other parts of the demo own: a draft boundary with one segment, no landmark yet
      boundary = {
        'id': 'b0000000-0000-4000-8000-000000000001',
        'case_id': cid,
        'version': 1,
        'geom': {'type': 'Polygon', 'coordinates': <dynamic>[]},
        'status': 'draft',
        'is_current': true,
        'sealed_hash': null,
        'approved_on': null,
        'segments': [
          {'id': 's1', 'seq': 0, 'geom': <String, dynamic>{}, 'length_m': 10.0},
        ],
        'landmarks': <dynamic>[],
        'use_zones': <dynamic>[],
      };
      e.table('cfr_boundary').add(boundary);
      e.table('media')
        ..add({'id': otherSheet, 'uploaded_by_user_id': _userId(e, _villagerPhone)})
        ..add({'id': ownSheet, 'uploaded_by_user_id': _userId(e, _gsPhone)});
      e.table('correspondence').add({
        'id': g7,
        'gram_sabha_id': DemoAccounts.gramSabhaId,
        'template': 'g7_site_visit',
        'dispatched_on': '2026-10-01',
      });
    });

    tearDown(() => DemoMode.idForTest = null);

    void addLandmark() => (boundary['landmarks'] as List).add({
          'id': 'l1',
          'segment_seq': 0,
          'name': 'Nala',
          'point': {
            'type': 'Point',
            'coordinates': [71.0, 18.0]
          },
        });

    test('the check lists everything missing and approval is blocked', () async {
      final c = await check();
      expect(c['ready'], isFalse);
      expect(itemsOk(c),
          {'resolution': false, 'boundary': false, 'verification': false, 'disputes': true});
      final rules = {for (final i in (c['items'] as List).cast<Map>()) i['id']: i['rule']};
      expect(rules, {
        'resolution': 'Sec 6(1), Rule 4(2)',
        'boundary': 'Rule 12(1)(g)',
        'verification': 'Rule 12A(1)(2)',
        'disputes': 'Rule 12(3)',
      });
      for (final i in (c['items'] as List).cast<Map>()) {
        expect(i.keys, containsAll(['id', 'ok', 'rule', 'message_key']));
      }
      expect((await check(villager))['ready'], isFalse); // the claimant sees the same list

      final blocked = await e.fails('POST', '/cases/$cid/approve', token: gs);
      expect((blocked.statusCode, blocked.error), (409, 'GS_PREREQUISITES_MISSING'));
      expect(blocked.messageKey, 'approval.prerequisites_missing');
      expect(blocked.rule, 'Sec 6(1), Rule 4(2)');
      final missing = (blocked.details!['missing'] as List).cast<Map>();
      expect(missing.map((m) => m['id']), ['resolution', 'boundary', 'verification']);
      expect(missing.every((m) => m['ok'] == false), isTrue);
    });

    test('a resolution needs a boundary, a landmark on every segment and no open overlap',
        () async {
      boundary['is_current'] = false;
      var err =
          await e.fails('POST', '/meetings/$mid/resolutions', token: gs, body: resolutionBody());
      expect((err.statusCode, err.error), (409, 'NO_BOUNDARY'));
      boundary['is_current'] = true;

      err = await e.fails('POST', '/meetings/$mid/resolutions', token: gs, body: resolutionBody());
      expect((err.statusCode, err.error, err.rule), (409, 'LANDMARK_PER_SEGMENT', 'Rule 12(1)(g)'));
      addLandmark();

      e.table('claim_case').add({
        'id': 'c0000000-0000-4000-8000-0000000000aa',
        'gram_sabha_id': 'other',
        'claim_type': 'cfr',
        'state': 'gs_review',
        'created_by_user_id': 'x',
        'reached_stage': 1,
      });
      e.table('dispute').add({
        'id': 'd0000000-0000-4000-8000-000000000001',
        'case_id': cid,
        'neighbour_case_id': 'c0000000-0000-4000-8000-0000000000aa',
        'overlap_ha': '1.5000',
        'outcome': null,
        'sdlc_referral_on': null,
      });
      expect(itemsOk(await check())['disputes'], isFalse);
      err = await e.fails('POST', '/meetings/$mid/resolutions', token: gs, body: resolutionBody());
      expect((err.statusCode, err.error, err.rule), (409, 'OPEN_DISPUTE', 'Rule 12(3)'));
      expect(boundary['status'], 'draft');

      // a neighbour's claim that was rejected no longer counts
      e.table('claim_case').last['state'] = 'rejected';
      final ok = await e.call('POST', '/meetings/$mid/resolutions',
          token: gs, body: resolutionBody()) as Map;
      expect(ok['boundary_id'], boundary['id']);
    });

    test('verification visits (BR-07)', () async {
      // validation answers like Pydantic
      var err = await e.fails('POST', '/cases/$cid/verification',
          token: gs, body: {'visit_on': '2026-10-10', 'observations': '', 'presence': <dynamic>[]});
      expect(err.statusCode, 422);
      final locs = [
        for (final x in (err.details!['errors'] as List).cast<Map>()) (x['loc'] as List).join('.'),
      ];
      expect(locs, containsAll(['body.observations', 'body.presence']));
      err = await e.fails('POST', '/cases/$cid/verification',
          token: gs,
          body: visitBody({
            'presence': [
              {'name': 'A', 'department': 'police'},
            ],
          }));
      expect((err.details!['errors'] as List).single['type'], 'literal_error');
      expect(
          (await e.fails('POST', '/cases/$cid/verification', token: villager, body: visitBody()))
              .statusCode,
          403);

      // signatures need the signed sheet, which must be the caller's own upload
      err = await e.fails('POST', '/cases/$cid/verification',
          token: gs, body: visitBody({'forest_signed': true}));
      expect((err.statusCode, err.error), (422, 'SIGNED_SHEET_MISSING'));
      err = await e.fails('POST', '/cases/$cid/verification',
          token: gs, body: visitBody({'forest_signed': true, 'signed_scan_media_id': otherSheet}));
      expect(err.error, 'MEDIA_NOT_YOURS');
      err = await e.fails('POST', '/cases/$cid/verification',
          token: gs,
          body: visitBody({
            'revenue_signed': true,
            'revenue_absence_recorded': true,
            'signed_scan_media_id': ownSheet,
          }));
      expect((err.statusCode, err.error), (422, 'SIGNED_AND_ABSENT'));
      expect(err.details!['dept'], 'revenue');

      // first visit: revenue neither signed nor recorded absent: not complete
      final first = await e.call('POST', '/cases/$cid/verification',
          token: gs,
          body: visitBody({'forest_signed': true, 'signed_scan_media_id': ownSheet})) as Map;
      expect((first['attempt_no'], first['complete'], first['finality_note']), (1, false, false));
      expect(first['presence'], [
        {'name': 'RFO Patil', 'designation': 'RFO', 'department': 'forest'},
      ]);
      expect(itemsOk(await check())['verification'], isFalse);

      // an absence needs a G7 letter that was dispatched before the visit
      final absent = visitBody({
        'forest_signed': true,
        'signed_scan_media_id': ownSheet,
        'revenue_absence_recorded': true,
      });
      err = await e.fails('POST', '/cases/$cid/verification', token: gs, body: absent);
      expect((err.statusCode, err.error, err.rule), (409, 'INTIMATION_REQUIRED', 'Rule 12A(1)(2)'));
      final letter = e.table('correspondence').single;
      letter['dispatched_on'] = null;
      err = await e.fails('POST', '/cases/$cid/verification',
          token: gs, body: {...absent, 'intimation_id': g7});
      expect(err.error, 'INTIMATION_REQUIRED'); // never dispatched
      letter['dispatched_on'] = '2026-10-11';
      err = await e.fails('POST', '/cases/$cid/verification',
          token: gs, body: {...absent, 'intimation_id': g7});
      expect(err.error, 'INTIMATION_REQUIRED'); // dispatched after the visit
      letter['dispatched_on'] = '2026-10-01';
      letter['template'] = 'other';
      err = await e.fails('POST', '/cases/$cid/verification',
          token: gs, body: {...absent, 'intimation_id': g7});
      expect(err.error, 'INTIMATION_REQUIRED'); // not a G7 letter
      letter['template'] = 'g7_site_visit';

      final second = await e.call('POST', '/cases/$cid/verification',
          token: gs, body: {...absent, 'intimation_id': g7}) as Map;
      expect((second['attempt_no'], second['complete'], second['finality_note']), (2, true, true));
      expect(second['intimation_id'], g7);
      final visits = await e.call('GET', '/cases/$cid/verification', token: villager) as List;
      expect(visits.map((v) => (v as Map)['attempt_no']), [1, 2]);
      expect(itemsOk(await check())['verification'], isTrue);
    });

    test('a claimant who is a Gram Sabha member is recused (Rule 3(3))', () async {
      e.table('app_user').firstWhere((u) => u['phone'] == _gsPhone)['gs_member_id'] = ids[0];
      e.table('case_claimant').add({'case_id': cid, 'gs_member_id': ids[0]});
      final err = await e.fails('POST', '/cases/$cid/verification', token: gs, body: visitBody());
      expect((err.statusCode, err.error, err.rule), (409, 'CLAIMANT_RECUSED', 'Rule 3(3)'));
      expect(e.table('recusal'), hasLength(1));
      final again =
          await e.fails('POST', '/meetings/$mid/resolutions', token: gs, body: resolutionBody());
      expect(again.error, 'CLAIMANT_RECUSED');
      expect(e.table('recusal'), hasLength(1)); // recorded once
    });

    test('resolution freezes the boundary, approval opens, the ledger notices tampering', () async {
      addLandmark();
      await e.call('POST', '/cases/$cid/verification',
          token: gs,
          body: visitBody({
            'forest_signed': true,
            'revenue_signed': true,
            'signed_scan_media_id': ownSheet,
          }));
      expect(itemsOk(await check()),
          {'resolution': false, 'boundary': false, 'verification': true, 'disputes': true});

      final r = await e.call('POST', '/meetings/$mid/resolutions',
          token: gs, body: resolutionBody()) as Map;
      expect(r['number'], '1/2026');
      expect(r['boundary_id'], boundary['id']);
      expect((r['quorum_proof'] as Map)['passed'], isTrue);
      expect(boundary['status'], 'gs_approved');
      expect(boundary['sealed_hash'], hasLength(64));
      expect(boundary['approved_on'], '2026-10-14');

      final c = await check();
      expect(c['ready'], isTrue);
      expect(itemsOk(c).values.every((v) => v == true), isTrue);
      final approved = await e.call('POST', '/cases/$cid/approve', token: gs) as Map;
      expect(approved['state'], 'sdo_review');
      final history = await e.call('GET', '/cases/$cid/history', token: gs) as List;
      expect(history.map((h) => (h as Map)['action']), ['submit', 'approve']);

      // submit, verification, resolution, approve
      var chain = await e.call('GET', '/villages/$_village/ledger/verify', token: villager) as Map;
      expect((chain['ok'], chain['length']), (true, 4));
      expect(e.table('ledger_entry').map((x) => x['entity']),
          ['workflow_event', 'verification_proceeding', 'resolution', 'workflow_event']);
      expect(chain['head'], e.table('ledger_entry').last['record_hash']);

      // anyone changing a stored record is found, with the place in the chain
      final resolution = e.table('resolution').single;
      resolution['votes_for'] = 5;
      chain = await e.call('GET', '/villages/$_village/ledger/verify', token: gs) as Map;
      expect(chain['ok'], isFalse);
      expect(chain['broken_at_seq'], 3);
      expect(chain['broken_entity'], 'resolution');
      expect(chain['reason'], 'record altered');
      resolution['votes_for'] = 3;
      chain = await e.call('GET', '/villages/$_village/ledger/verify', token: gs) as Map;
      expect(chain['ok'], isTrue);

      e.table('workflow_event').first['remarks'] = 'edited later';
      chain = await e.call('GET', '/villages/$_village/ledger/verify', token: gs) as Map;
      expect((chain['ok'], chain['broken_at_seq'], chain['broken_entity']),
          (false, 1, 'workflow_event'));
    });
  });

  group('ledger and approval check access', () {
    test('every village role verifies the chain; a visitor and the back office cannot', () async {
      final h = DemoHarness();
      addTearDown(h.dispose);
      final villager = await h.login(_villagerPhone);
      final admin = await h.login('9000000004');
      final chain =
          await h.call('GET', '/villages/$_village/ledger/verify', token: villager) as Map;
      expect((chain['ok'], chain['length']), (true, 0));
      expect(chain['head'], '0' * 64);
      expect((await h.fails('GET', '/villages/$_village/ledger/verify')).statusCode, 401);
      final admin403 = await h.fails('GET', '/villages/$_village/ledger/verify', token: admin);
      expect((admin403.statusCode, admin403.error), (403, 'FORBIDDEN'));
      final nobody = await h.fails(
          'GET', '/villages/00000000-0000-4000-8000-000000000999/ledger/verify',
          token: villager);
      expect((nobody.statusCode, nobody.error), (404, 'VILLAGE_NOT_FOUND'));
      final notUuid = await h.fails('GET', '/villages/abc/meetings', token: villager);
      expect(notUuid.statusCode, 422);
    });

    test('the approval check hides a claim the caller may not see', () async {
      final h = DemoHarness();
      addTearDown(h.dispose);
      final villager = await h.login(_villagerPhone);
      final other = await h.login('9000000002');
      final gs = await h.login(_gsPhone);
      final c = await h.call('POST', '/villages/$_village/cases',
          token: villager, body: {'claim_type': 'cr'}) as Map;
      final url = '/cases/${c['id']}/approval-check';
      expect((await h.fails('GET', url, token: other)).statusCode, 404);
      expect((await h.fails('GET', url, token: gs)).statusCode, 404); // still a draft
      expect(((await h.call('GET', url, token: villager)) as Map)['ready'], isTrue);
      await h.call('POST', '/cases/${c['id']}/submit', token: villager);
      expect(((await h.call('GET', url, token: gs)) as Map)['items'], isEmpty);
    });

    test('approval prerequisites per claim form', () {
      final db = DemoDb({});
      for (final type in ['ifr', 'cr']) {
        expect(DemoGramSabha.approvalItems(db, {'id': 'x-$type', 'claim_type': type}), isEmpty);
      }
      expect(DemoGramSabha.approvalItems(db, {'id': 'x', 'claim_type': 'cfr'}).map((i) => i['id']),
          ['resolution', 'boundary', 'verification', 'disputes']);
    });
  });
}
