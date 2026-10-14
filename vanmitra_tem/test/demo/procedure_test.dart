import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';
import 'package:vanmitra_ai/demo/core/demo_cases.dart';
import 'package:vanmitra_ai/demo/core/demo_core.dart';
import 'package:vanmitra_ai/demo/procedure/demo_procedure.dart';
import 'package:vanmitra_ai/demo/procedure/procedure_domain.dart';

import 'demo_support.dart';

/// The procedure slice: claim calls, letters, village registry, FRC, claimants, post-title
/// follow-up and the clocks timeline. The domain tests are ports of the backend's
/// tests/unit/test_frc.py, test_clocks.py and test_dates_ist.py.

const _f = 'female', _m = 'male';
const _st = 'st', _otfd = 'otfd', _other = 'other';

List<FrcCandidate> _frc(List<(String, String)> spec) =>
    [for (var i = 0; i < spec.length; i++) FrcCandidate('$i', spec[i].$1, spec[i].$2)];

List<(String, String)> _times(int n, String gender, String category) =>
    List.filled(n, (gender, category));

List<String> _failures(List<FrcCandidate> c, {bool hasSt = true}) =>
    FrcRules.check(c, gramSabhaHasSt: hasSt, chairId: '0', secretaryId: '1').failures;

DateTime _d(int y, int m, int d) => DateTime.utc(y, m, d);

/// A demo database with the real routes, called directly (so tests can set up rows, such as
/// Gram Sabha members and a case whose title is issued, that no route in this slice creates).
class _Rig {
  _Rig({DateTime? start}) : _now = start ?? DateTime.utc(2026, 10, 14, 6, 30) {
    db = DemoDb({}, clock: () => _now);
    DemoAccounts.seed(db);
    DemoAccounts.register(router);
    DemoCases.register(router);
    DemoProcedure.register(router);
  }

  late final DemoDb db;
  final DemoRouter router = DemoRouter();
  DateTime _now;

  void advance(Duration d) => _now = _now.add(d);

  /// A demo user by number (1/2 village users, 3 Gram Sabha, 4 admin, 5 SDO).
  Future<dynamic> call(String method, String path, {Object? body, int user = 3}) async {
    final found = router.match(method, path);
    if (found == null) throw StateError('no route $method $path');
    final out = await found.handler(DemoRequest(
      method: method,
      path: path,
      params: found.params,
      query: Uri.parse(path).queryParametersAll,
      body: body,
      db: db,
      principal: DemoAccounts.principalOf(db, DemoAccounts.userIdFor(user)),
    ));
    return jsonDecode(jsonEncode(out));
  }

  Future<DemoError> fails(String method, String path, {Object? body, int user = 3}) async {
    try {
      await call(method, path, body: body, user: user);
    } on DemoError catch (e) {
      return e;
    }
    throw StateError('$method $path was expected to fail');
  }

  /// Twelve extra members: 4 women ST, 4 men ST, 4 men OTFD (a valid committee).
  List<String> addMembers() {
    final ids = <String>[];
    void add(String gender, String category, int n) {
      for (var i = 0; i < n; i++) {
        ids.add(db.add('gs_member', {
          'gram_sabha_id': DemoAccounts.gramSabhaId,
          'name': 'Member ${ids.length}',
          'gender': gender,
          'category': category,
          'active': true,
        })['id'] as String);
      }
    }

    add(_f, _st, 4);
    add(_m, _st, 4);
    add(_m, _otfd, 4);
    return ids;
  }

  static String get village => DemoAccounts.villageId;
}

void _expectError(DemoError e, int status, String error, {String? key, String? rule}) {
  expect(e.status, status);
  expect(e.error, error);
  if (key != null) expect(e.messageKey, key);
  if (rule != null) expect(e.rule, rule);
}

void main() {
  // ── ports of the backend unit tests ───────────────────────────────────────

  group('FRC composition (test_frc.py)', () {
    test('valid committee of twelve', () {
      // 12 members: 8 ST (= ceil(2*12/3)), 4 women (= ceil(12/3))
      final cands = _frc([..._times(4, _f, _st), ..._times(4, _m, _st), ..._times(4, _m, _otfd)]);
      final result = FrcRules.check(cands, gramSabhaHasSt: true, chairId: '0', secretaryId: '1');
      expect(result.ok, isTrue, reason: '${result.failures}');
      expect((result.requiredSt, result.requiredWomen), (8, 4));
    });

    test('size limits', () {
      expect(_failures(_frc(_times(9, _f, _st))), contains('frc.too_few_members'));
      expect(_failures(_frc(_times(16, _f, _st))), contains('frc.too_many_members'));
      expect(_failures(_frc(_times(10, _f, _st))), isEmpty);
      expect(_failures(_frc(_times(15, _f, _st))), isEmpty);
    });

    test('two thirds Scheduled Tribes', () {
      // 7 ST of 12, needs 8
      final cands = _frc([..._times(4, _f, _st), ..._times(3, _m, _st), ..._times(5, _m, _otfd)]);
      expect(_failures(cands), contains('frc.too_few_st'));
    });

    test('ST rule skipped when the Gram Sabha has no ST', () {
      final cands = _frc([..._times(4, _f, _otfd), ..._times(6, _m, _other)]);
      expect(_failures(cands, hasSt: false), isEmpty);
      expect(_failures(cands, hasSt: true), contains('frc.too_few_st'));
    });

    test('one third women', () {
      final cands = _frc([..._times(3, _f, _st), ..._times(9, _m, _st)]); // 3 of 12, needs 4
      expect(_failures(cands), contains('frc.too_few_women'));
    });

    test('chair and secretary must be distinct members', () {
      final cands = _frc([..._times(4, _f, _st), ..._times(6, _m, _st)]);
      final same = FrcRules.check(cands, gramSabhaHasSt: true, chairId: '0', secretaryId: '0');
      expect(same.failures, contains('frc.chair_and_secretary_same'));
      final outsider = FrcRules.check(cands, gramSabhaHasSt: true, chairId: '99', secretaryId: null);
      expect(
        outsider.failures,
        containsAll(['frc.chair_not_a_member', 'frc.secretary_not_a_member']),
      );
    });

    test('a duplicate member is caught', () {
      final cands = _frc([..._times(4, _f, _st), ..._times(6, _m, _st)]);
      cands.add(cands[0]);
      expect(_failures(cands), contains('frc.duplicate_member'));
    });

    test('proof is serialisable', () {
      final proof = FrcRules.check(_frc(_times(10, _f, _st)),
              gramSabhaHasSt: true, chairId: '0', secretaryId: '1')
          .proof();
      expect(proof['members'], 10);
      expect(proof['ok'], isTrue);
      expect(jsonEncode(proof), isNotEmpty);
    });

    test('recusal', () {
      expect(FrcRules.mustRecuse('m1', ['m1', 'm2']), isTrue);
      expect(FrcRules.mustRecuse('m3', ['m1', 'm2']), isFalse);
      expect(FrcRules.mustRecuse(null, ['m1']), isFalse);
    });
  });

  group('statutory clocks (test_clocks.py)', () {
    final today = _d(2026, 10, 3);

    test('petition is sixty days from the resolution', () {
      expect(ProcedureClocks.petitionDue(_d(2026, 9, 1)), _d(2026, 10, 31));
    });

    test('claim window is three months', () {
      expect(ProcedureClocks.claimWindowDue(_d(2026, 11, 30)), _d(2027, 2, 28));
    });

    test('running clock reports days and next alert', () {
      final start = today.subtract(const Duration(days: 40));
      final c = ProcedureClocks.clock(
        'petition',
        'Sec 6(2)',
        start,
        ProcedureClocks.petitionDue(start),
        today,
        alerts: ProcedureClocks.alertDays,
      );
      expect(c.status, ClockStatus.running);
      expect(c.daysRemaining, 20);
      expect(c.nextAlertOn, start.add(const Duration(days: 45)));
    });

    test('overdue and met', () {
      final start = today.subtract(const Duration(days: 70));
      final overdue = ProcedureClocks.clock(
          'petition', 'Sec 6(2)', start, ProcedureClocks.petitionDue(start), today);
      expect(overdue.status, ClockStatus.overdue);
      expect(overdue.daysRemaining, -10);
      expect(overdue.nextAlertOn, isNull);
      final met = ProcedureClocks.clock(
        'x',
        'r',
        start,
        ProcedureClocks.petitionDue(start),
        today,
        metOn: today.subtract(const Duration(days: 5)),
      );
      expect(met.status, ClockStatus.met);
    });

    test('the due day itself is still running', () {
      expect(ProcedureClocks.clock('x', 'r', today, today, today).status, ClockStatus.running);
    });

    test('a clock is written the way the timeline sends it', () {
      final c = ProcedureClocks.clock('x', 'r', today, _d(2026, 10, 10), today);
      expect(c.toJson(), {
        'kind': 'x',
        'rule': 'r',
        'starts_on': '2026-10-03',
        'due_on': '2026-10-10',
        'status': 'running',
        'days_remaining': 7,
        'next_alert_on': null,
      });
    });
  });

  group('days follow the Indian calendar (test_dates_ist.py)', () {
    test('late evening UTC is already the next day in India', () {
      // 19:00 UTC on 7 October is 00:30 IST on 8 October
      expect(istDateOf(DateTime.utc(2026, 10, 7, 19).toIso8601String()), '2026-10-08');
    });

    test('early UTC morning is the same day in India', () {
      expect(istDateOf(DateTime.utc(2026, 10, 7, 3).toIso8601String()), '2026-10-07');
    });

    test('months are added clamped to the last day', () {
      expect(dateOnly(addMonths(_d(2026, 1, 31), 1)), '2026-02-28');
      expect(dateOnly(addMonths(_d(2027, 11, 30), 3)), '2028-02-29');
    });
  });

  // ── routes through the demo server ────────────────────────────────────────

  group('claim calls', () {
    late DemoHarness h;
    late String villager;
    late String gs;
    late String sdo;
    const base = '/villages/${DemoAccounts.villageId}/claim-calls';

    setUp(() async {
      h = DemoHarness();
      villager = await h.login('9000000001');
      gs = await h.login('9000000003');
      sdo = await h.login('9000000005');
    });
    tearDown(() => h.dispose());

    Map<String, dynamic> open({String called = '2026-10-14'}) =>
        {'called_on': called, 'place_of_filing': '  Gram Panchayat office, Ozhar '};

    test('nothing yet: 404 NO_CLAIM_CALL', () async {
      final e = await h.fails('GET', '$base/current', token: villager);
      expect(e.statusCode, 404);
      expect(e.error, 'NO_CLAIM_CALL');
      expect(e.messageKey, 'claim_call.none');
      expect(await h.call('GET', base, token: gs), isEmpty);
    });

    test('the Gram Sabha opens a call: three months, 92 days left', () async {
      final out = await h.call('POST', base, token: gs, body: open()) as Map;
      expect(out['called_on'], '2026-10-14');
      expect(out['window_ends_on'], '2027-01-14');
      expect(out['closes_on'], '2027-01-14');
      expect(out['days_remaining'], 92);
      expect(out['is_open'], isTrue);
      expect(out['place_of_filing'], 'Gram Panchayat office, Ozhar');
      expect(out['is_current'], isTrue);
      expect(out['extended_to'], isNull);
      expect(out.keys.toSet(), {
        'id', 'called_on', 'window_ends_on', 'closes_on', 'days_remaining', 'is_open',
        'place_of_filing', 'notice_displayed_on', 'cfr_determination_on', 'extended_to',
        'extension_reason', 'extension_resolution_ref', 'is_current', //
      });
      final cur = await h.call('GET', '$base/current', token: villager) as Map;
      expect(cur['id'], out['id']);
      final sdoSees = await h.call('GET', '$base/current', token: sdo) as Map;
      expect(sdoSees['id'], out['id']);
    });

    test('a call for a later date is not open yet; one in the past ran out', () async {
      final later = await h.call('POST', base, token: gs, body: open(called: '2026-11-01')) as Map;
      expect(later['is_open'], isFalse);
      final past = await h.call('POST', base, token: gs, body: open(called: '2026-05-01')) as Map;
      expect(past['window_ends_on'], '2026-08-01');
      expect(past['is_open'], isFalse);
      expect(past['days_remaining'], 0);
    });

    test('the villager and the SDO cannot open or change a call', () async {
      for (final token in [villager, sdo]) {
        final e = await h.fails('POST', base, token: token, body: open());
        expect(e.statusCode, 403);
        expect(e.error, 'FORBIDDEN');
        expect(e.messageKey, 'auth.forbidden_in_village');
        expect(e.details?['required_roles'], ['gram_sabha']);
      }
      expect((await h.fails('POST', base, body: open())).statusCode, 401);
    });

    test('a new call replaces the current one; history is newest first', () async {
      final first = await h.call('POST', base, token: gs, body: open(called: '2026-09-01')) as Map;
      final second = await h.call('POST', base, token: gs, body: open()) as Map;
      final history = await h.call('GET', base, token: villager) as List;
      expect(history.map((c) => c['id']), [second['id'], first['id']]);
      expect(history.map((c) => c['is_current']), [true, false]);
      expect((await h.call('GET', '$base/current', token: gs) as Map)['id'], second['id']);
    });

    test('validation: place and date are needed; notice cannot precede the call', () async {
      final e = await h.fails('POST', base, token: gs, body: {'called_on': 'tomorrow'});
      expect(e.statusCode, 422);
      expect(e.error, 'VALIDATION_ERROR');
      final errors = e.details!['errors'] as List;
      expect(errors.map((x) => (x['loc'] as List).last), containsAll(['called_on', 'place_of_filing']));
      final before = await h.fails('POST', base,
          token: gs, body: {...open(), 'notice_displayed_on': '2026-10-13'});
      expect(before.statusCode, 422);
      expect(before.error, 'NOTICE_BEFORE_CALL');
      expect(before.messageKey, 'claim_call.notice_before_call');
    });

    test('extend: later date, written reasons and the resolution', () async {
      await h.call('POST', base, token: gs, body: open());
      final ext = {
        'extended_to': '2027-02-14',
        'reason': 'Floods kept people from the office',
        'resolution_ref': 'GS 4/2026',
      };
      final out = await h.call('POST', '$base/current/extend', token: gs, body: ext) as Map;
      expect(out['extended_to'], '2027-02-14');
      expect(out['closes_on'], '2027-02-14');
      expect(out['window_ends_on'], '2027-01-14');
      expect(out['days_remaining'], 123);
      expect(out['extension_reason'], 'Floods kept people from the office');
      expect(out['extension_resolution_ref'], 'GS 4/2026');

      final notLater = await h.fails('POST', '$base/current/extend',
          token: gs, body: {...ext, 'extended_to': '2027-02-14'});
      expect(notLater.statusCode, 409);
      expect(notLater.error, 'EXTENSION_NOT_LATER');
      expect(notLater.rule, 'Rule 11(1)(a)');
      expect(notLater.details?['closes_on'], '2027-02-14');

      final short = await h.fails('POST', '$base/current/extend',
          token: gs, body: {...ext, 'extended_to': '2027-03-01', 'reason': 'no'});
      expect(short.statusCode, 422);
      expect(short.error, 'VALIDATION_ERROR');
      expect((await h.fails('POST', '$base/current/extend', token: villager, body: ext)).statusCode,
          403);
    });

    test('extend with no call open is 404', () async {
      final e = await h.fails('POST', '$base/current/extend',
          token: gs,
          body: {'extended_to': '2027-02-14', 'reason': 'Floods', 'resolution_ref': 'GS 4'});
      expect(e.statusCode, 404);
      expect(e.error, 'NO_CLAIM_CALL');
    });

    test('record when the notice was displayed', () async {
      await h.call('POST', base, token: gs, body: open());
      final out = await h.call('POST', '$base/current/displayed',
          token: gs, body: {'notice_displayed_on': '2026-10-15'}) as Map;
      expect(out['notice_displayed_on'], '2026-10-15');
      final early = await h.fails('POST', '$base/current/displayed',
          token: gs, body: {'notice_displayed_on': '2026-10-01'});
      expect(early.statusCode, 422);
      expect(early.error, 'NOTICE_BEFORE_CALL');
      expect((await h.fails('POST', '$base/current/displayed', token: villager, body: {
        'notice_displayed_on': '2026-10-15',
      }))
          .statusCode, 403);
    });

    test('the days left count down with the (moved) clock', () async {
      await h.call('POST', base, token: gs, body: open());
      h.advance(const Duration(days: 30));
      final cur = await h.call('GET', '$base/current', token: gs) as Map;
      expect(cur['days_remaining'], 62);
      h.advance(const Duration(days: 100));
      final done = await h.call('GET', '$base/current', token: gs) as Map;
      expect(done['days_remaining'], 0);
      expect(done['is_open'], isFalse);
    });

    test('unknown village is 404; a user of another village is refused', () async {
      final e = await h.fails('GET', '/villages/00000000-0000-4000-8000-000000000099/claim-calls',
          token: gs);
      expect(e.statusCode, 404);
      expect(e.error, 'VILLAGE_NOT_FOUND');
      final admin = await h.login('9000000004');
      final created = await h.call('POST', '/admin/villages', token: admin, body: {
        'name_mr': 'पाडा',
        'name_en': 'Pada',
        'gram_panchayat': 'Pada',
        'taluka': 'Jawhar',
        'district': 'Palghar',
      }) as Map;
      final other = await h.fails('GET', '/villages/${created['id']}/claim-calls', token: villager);
      expect(other.statusCode, 403);
      // the SDO of the taluka covers it
      expect(await h.call('GET', '/villages/${created['id']}/claim-calls', token: sdo), isEmpty);
    });
  });

  group('village registry', () {
    late DemoHarness h;
    late String admin;
    late String villager;
    late String gs;

    setUp(() async {
      h = DemoHarness();
      admin = await h.login('9000000004');
      villager = await h.login('9000000001');
      gs = await h.login('9000000003');
    });
    tearDown(() => h.dispose());

    Map<String, dynamic> pada({String? lgd, String? parent}) => {
          'name_mr': 'खडकी पाडा',
          'name_en': 'Khadki Pada',
          'gram_panchayat': ' Ozhar ',
          'taluka': 'Jawhar',
          'district': 'Palghar',
          if (lgd != null) 'lgd_code': lgd,
          if (parent != null) 'parent_village_id': parent,
        };

    test('the admin creates a village; its Gram Sabha comes with it', () async {
      final out = await h.call('POST', '/admin/villages', token: admin, body: pada(lgd: '551900'))
          as Map;
      expect(out['name_en'], 'Khadki Pada');
      expect(out['gram_panchayat'], 'Ozhar');
      expect(out['state'], 'Maharashtra');
      expect(out['lgd_code'], '551900');
      expect(out['consolidation_status'], 'recognised');
      expect(out['parent_village_id'], isNull);
      expect(out['gram_sabha_id'], isNotNull);
      expect(out.keys.toSet(), {
        'id', 'name_mr', 'name_en', 'gram_panchayat', 'taluka', 'district', 'state', 'lgd_code',
        'parent_village_id', 'consolidation_status', 'gram_sabha_id', //
      });
      // it shows in the public list that registration reads
      final all = await h.call('GET', '/public/villages') as List;
      expect(all.map((v) => v['name_en']), contains('Khadki Pada'));
    });

    test('only the admin; no one else, not even the Gram Sabha', () async {
      for (final token in [villager, gs]) {
        final e = await h.fails('POST', '/admin/villages', token: token, body: pada());
        expect(e.statusCode, 403);
        expect(e.messageKey, 'auth.admin_only');
      }
      expect((await h.fails('POST', '/admin/villages', body: pada())).statusCode, 401);
    });

    test('a village code is used once; a hamlet needs a village to belong to', () async {
      await h.call('POST', '/admin/villages', token: admin, body: pada(lgd: '551900'));
      final dup = await h.fails('POST', '/admin/villages', token: admin, body: pada(lgd: '551900'));
      expect(dup.statusCode, 409);
      expect(dup.error, 'LGD_CODE_TAKEN');
      final orphan = await h.fails('POST', '/admin/villages',
          token: admin, body: pada(parent: '00000000-0000-4000-8000-000000000099'));
      expect(orphan.statusCode, 422);
      expect(orphan.error, 'PARENT_VILLAGE_NOT_FOUND');
    });

    test('validation: names are required, status must be known', () async {
      final e = await h.fails('POST', '/admin/villages',
          token: admin, body: {'name_en': 'X', 'consolidation_status': 'maybe'});
      expect(e.statusCode, 422);
      expect(e.error, 'VALIDATION_ERROR');
      final fields = (e.details!['errors'] as List).map((x) => (x['loc'] as List).last).toSet();
      expect(fields, containsAll(['name_mr', 'gram_panchayat', 'taluka', 'district',
          'consolidation_status']));
    });

    test('hamlets are listed under their village, by name', () async {
      const parent = DemoAccounts.villageId;
      await h.call('POST', '/admin/villages',
          token: admin, body: {...pada(parent: parent), 'name_en': 'Zed Pada'});
      await h.call('POST', '/admin/villages',
          token: admin, body: {...pada(parent: parent), 'name_en': 'Aam Pada'});
      final list = await h.call('GET', '/villages/$parent/hamlets', token: villager) as List;
      expect(list.map((v) => v['name_en']), ['Aam Pada', 'Zed Pada']);
      expect(list.every((v) => v['parent_village_id'] == parent), isTrue);
    });

    test('the admin changes a village; blank fields are left as they are', () async {
      final v = await h.call('POST', '/admin/villages', token: admin, body: pada()) as Map;
      final out = await h.call('PATCH', '/admin/villages/${v['id']}', token: admin, body: {
        'name_en': 'Khadki',
        'taluka': null,
        'consolidation_status': 'listed',
      }) as Map;
      expect(out['name_en'], 'Khadki');
      expect(out['taluka'], 'Jawhar');
      expect(out['consolidation_status'], 'listed');
      expect((await h.fails('PATCH', '/admin/villages/${v['id']}', token: gs, body: {})).statusCode,
          403);
      expect((await h.fails('PATCH', '/admin/villages/00000000-0000-4000-8000-000000000099',
              token: admin, body: {'name_en': 'Q'}))
          .statusCode, 404);
    });

    test('a village user reads their own village', () async {
      final out = await h.call('GET', '/villages/${DemoAccounts.villageId}', token: villager) as Map;
      expect(out['name_en'], 'Ozhar');
      expect(out['gram_sabha_id'], DemoAccounts.gramSabhaId);
    });

    test('FRC: nothing yet, and a roster that does not match is refused', () async {
      const base = '/villages/${DemoAccounts.villageId}/frc';
      final none = await h.fails('GET', base, token: villager);
      expect(none.statusCode, 404);
      expect(none.error, 'FRC_NOT_CONSTITUTED');
      expect(await h.call('GET', '$base/history', token: villager), isEmpty);
      final e = await h.fails('POST', '$base/check', token: gs, body: {
        'member_ids': ['00000000-0000-4000-8000-000000000099'],
      });
      expect(e.statusCode, 422);
      expect(e.error, 'FRC_MEMBER_NOT_IN_ROSTER');
      expect(e.details, {'known': 0, 'given': 1});
      expect((await h.fails('POST', '$base/check', token: villager, body: {'member_ids': []}))
          .statusCode, 403);
    });
  });

  group('Forest Rights Committee', () {
    late _Rig rig;
    late List<String> ids;
    final base = '/villages/${_Rig.village}/frc';

    setUp(() {
      rig = _Rig();
      ids = rig.addMembers();
    });

    Map<String, dynamic> body(List<String> members, {String? chair, String? secretary}) => {
          'member_ids': members,
          'chair_id': chair ?? members.first,
          'secretary_id': secretary ?? members[1],
        };

    test('check: a valid composition, nothing is saved', () async {
      final out = await rig.call('POST', '$base/check', body: body(ids)) as Map;
      expect(out, {
        'ok': true,
        'members': 12,
        'st': 8,
        'women': 4,
        'required_st': 8,
        'required_women': 4,
        'st_rule_applies': true,
        'failures': <String>[],
      });
      expect(rig.db.table('frc'), isEmpty);
    });

    test('check: failures are listed as message keys', () async {
      // 11 members, one without a chair: too few women (4 needed, 4 of 12?) etc.
      final out = await rig.call('POST', '$base/check', body: {
        'member_ids': ids.sublist(4), // 8 men only
      }) as Map;
      expect(out['ok'], isFalse);
      expect(out['members'], 8);
      expect(out['failures'], containsAll([
        'frc.too_few_members',
        'frc.too_few_women',
        'frc.chair_not_a_member',
        'frc.secretary_not_a_member',
      ]));
    });

    test('constitute with a valid composition (Rule 3(1))', () async {
      final out = await rig.call('POST', base,
          body: {
            ...body(ids, chair: ids[1], secretary: ids[0]),
            'constituted_on': '2026-10-10',
            'resolution_ref': ' GS 3/2026 ',
          }) as Map;
      expect(out['constituted_on'], '2026-10-10');
      expect(out['resolution_ref'], 'GS 3/2026');
      expect(out['is_current'], isTrue);
      expect(out['sdlc_intimated_on'], isNull);
      expect((out['composition'] as Map)['ok'], isTrue);
      final members = out['members'] as List;
      expect(members, hasLength(12));
      expect(members[0]['gs_member_id'], ids[1]);
      expect(members[0]['is_chair'], isTrue);
      expect(members[1]['gs_member_id'], ids[0]);
      expect(members[1]['is_secretary'], isTrue);
      expect(members.skip(2).every((m) => !m['is_chair'] && !m['is_secretary']), isTrue);
      expect(members[0].keys.toSet(),
          {'gs_member_id', 'name', 'gender', 'category', 'is_chair', 'is_secretary'});

      final cur = await rig.call('GET', base, user: 1) as Map;
      expect(cur['id'], out['id']);
      expect((await rig.call('GET', base, user: 5) as Map)['id'], out['id']);
    });

    test('constitute with too few Scheduled Tribes is refused', () async {
      // 7 ST of 12 (needs 8): swap one ST man for another OTFD man
      final members = [...ids.sublist(0, 7), ...ids.sublist(8)]; // drops one ST man
      final extra = rig.db.add('gs_member', {
        'gram_sabha_id': DemoAccounts.gramSabhaId,
        'name': 'Extra',
        'gender': _m,
        'category': _otfd,
        'active': true,
      })['id'] as String;
      final e = await rig.fails('POST', base,
          body: {...body([...members, extra]), 'constituted_on': '2026-10-10'});
      _expectError(e, 409, 'FRC_COMPOSITION_INVALID', key: 'frc.too_few_st', rule: 'Rule 3(1)');
      expect(e.details['failures'], ['frc.too_few_st']);
      expect(e.details['st'], 7);
      expect(e.details['required_st'], 8);
      expect(rig.db.table('frc'), isEmpty);
    });

    test('constitute with too few members, no chair or the same person twice', () async {
      final few = await rig.fails('POST', base,
          body: {...body(ids.sublist(0, 9)), 'constituted_on': '2026-10-10'});
      _expectError(few, 409, 'FRC_COMPOSITION_INVALID', key: 'frc.too_few_members');
      final same = await rig.fails('POST', base, body: {
        ...body(ids, chair: ids[0], secretary: ids[0]),
        'constituted_on': '2026-10-10',
      });
      _expectError(same, 409, 'FRC_COMPOSITION_INVALID', key: 'frc.chair_and_secretary_same');
      final noChair = await rig.fails('POST', base,
          body: {'member_ids': ids, 'constituted_on': '2026-10-10'});
      expect(noChair.details['failures'],
          containsAll(['frc.chair_not_a_member', 'frc.secretary_not_a_member']));
    });

    test('a person outside the roster, an inactive member or a duplicate id', () async {
      final foreign = rig.db.add('gs_member', {
        'gram_sabha_id': '00000000-0000-4000-8000-0000000000aa',
        'name': 'Elsewhere',
        'gender': _f,
        'category': _st,
        'active': true,
      })['id'] as String;
      final e = await rig.fails('POST', '$base/check', body: body([...ids.sublist(0, 11), foreign]));
      _expectError(e, 422, 'FRC_MEMBER_NOT_IN_ROSTER', key: 'frc.member_not_in_roster');
      expect(e.details, {'known': 12, 'given': 12});

      rig.db.byId('gs_member', ids[11])!['active'] = false;
      final gone = await rig.fails('POST', '$base/check', body: body(ids));
      expect(gone.details, {'known': 11, 'given': 12});

      final dup = await rig.call('POST', '$base/check', body: body([...ids.sublist(0, 11), ids[0]]))
          as Map;
      expect(dup['failures'], contains('frc.duplicate_member'));
    });

    test('validation: the date, the list and the ids', () async {
      final e = await rig.fails('POST', base, body: {'member_ids': 'all', 'chair_id': 'abc'});
      expect(e.status, 422);
      expect(e.error, 'VALIDATION_ERROR');
      final fields = (e.details['errors'] as List).map((x) => (x['loc'] as List).last).toSet();
      expect(fields, {'member_ids', 'chair_id', 'constituted_on'});
      final tooMany = await rig.fails('POST', '$base/check',
          body: {'member_ids': List.filled(31, ids[0])});
      expect(tooMany.status, 422);
    });

    test('only the Gram Sabha constitutes or checks', () async {
      for (final user in [1, 5]) {
        final e = await rig.fails('POST', '$base/check', user: user, body: body(ids));
        expect(e.status, 403);
        final c = await rig.fails('POST', base,
            user: user, body: {...body(ids), 'constituted_on': '2026-10-10'});
        expect(c.status, 403);
      }
    });

    test('a new committee supersedes the old; history keeps both, newest first', () async {
      final first = await rig.call('POST', base,
          body: {...body(ids), 'constituted_on': '2026-09-01'}) as Map;
      rig.advance(const Duration(minutes: 5));
      final second = await rig.call('POST', base,
          body: {...body(ids, chair: ids[2], secretary: ids[3]), 'constituted_on': '2026-10-01'})
          as Map;
      final history = await rig.call('GET', '$base/history', user: 1) as List;
      expect(history.map((f) => f['id']), [second['id'], first['id']]);
      expect(history.map((f) => f['is_current']), [true, false]);
      expect((await rig.call('GET', base, user: 1) as Map)['id'], second['id']);
    });

    test('intimation to the SDLC: not before the committee existed', () async {
      expect((await rig.fails('POST', '$base/intimation', body: {'sdlc_intimated_on': '2026-10-12'}))
          .error, 'FRC_NOT_CONSTITUTED');
      await rig.call('POST', base, body: {...body(ids), 'constituted_on': '2026-10-10'});
      final early = await rig.fails('POST', '$base/intimation',
          body: {'sdlc_intimated_on': '2026-10-09'});
      _expectError(early, 422, 'INTIMATION_BEFORE_CONSTITUTION',
          key: 'frc.intimation_before_constitution');
      final out = await rig.call('POST', '$base/intimation',
          body: {'sdlc_intimated_on': '2026-10-12'}) as Map;
      expect(out['sdlc_intimated_on'], '2026-10-12');
      expect(
        (await rig.fails('POST', '$base/intimation', user: 1, body: {'sdlc_intimated_on': '2026-10-12'}))
            .status,
        403,
      );
    });

    test('a village without a Gram Sabha: 409', () async {
      final orphan = rig.db.add('village', {
        'name_mr': 'x',
        'name_en': 'Orphan',
        'gram_panchayat': 'x',
        'taluka': DemoAccounts.taluka,
        'district': DemoAccounts.district,
        'state': 'Maharashtra',
        'lgd_code': null,
        'parent_village_id': null,
        'consolidation_status': 'recognised',
      });
      final e = await rig.fails('GET', '/villages/${orphan['id']}/frc', user: 5);
      _expectError(e, 409, 'GRAM_SABHA_MISSING', key: 'village.gram_sabha_missing');
    });
  });

  group('claimants of a case', () {
    late _Rig rig;
    late List<String> ids;
    late String caseId;

    setUp(() async {
      rig = _Rig();
      ids = rig.addMembers();
      final c = await rig.call('POST', '/villages/${_Rig.village}/cases',
          user: 1, body: {'claim_type': 'ifr'}) as Map;
      caseId = c['id'] as String;
    });

    test('empty at first; the claimant names the members who are claimants', () async {
      expect(await rig.call('GET', '/cases/$caseId/claimants', user: 1), isEmpty);
      final out = await rig.call('PUT', '/cases/$caseId/claimants',
          user: 1, body: {'member_ids': [ids[5], ids[0], ids[0]]}) as List;
      expect(out.map((m) => m['name']), ['Member 0', 'Member 5']);
      expect(out.first.keys.toSet(), {'gs_member_id', 'name', 'gender', 'category'});
      expect(out.first['gender'], _f);
      expect(out.first['category'], _st);
      expect(await rig.call('GET', '/cases/$caseId/claimants', user: 1), hasLength(2));
    });

    test('the list is replaced each time', () async {
      await rig.call('PUT', '/cases/$caseId/claimants', user: 1, body: {'member_ids': ids});
      final out = await rig.call('PUT', '/cases/$caseId/claimants',
          user: 1, body: {'member_ids': [ids[2]]}) as List;
      expect(out, hasLength(1));
      expect(rig.db.table('case_claimant'), hasLength(1));
      expect(await rig.call('PUT', '/cases/$caseId/claimants', user: 1, body: {'member_ids': []}),
          isEmpty);
    });

    test('someone who is not on the Gram Sabha roster is refused', () async {
      final e = await rig.fails('PUT', '/cases/$caseId/claimants',
          user: 1, body: {'member_ids': ['00000000-0000-4000-8000-000000000099']});
      _expectError(e, 422, 'CLAIMANT_NOT_IN_ROSTER', key: 'case.claimant_not_in_roster');
      final bad = await rig.fails('PUT', '/cases/$caseId/claimants', user: 1, body: {});
      expect(bad.error, 'VALIDATION_ERROR');
    });

    test('only the claimant sees and edits a draft', () async {
      expect((await rig.fails('GET', '/cases/$caseId/claimants', user: 3)).error, 'CASE_NOT_FOUND');
      expect((await rig.fails('GET', '/cases/$caseId/claimants', user: 2)).status, 404);
      expect(
        (await rig.fails('PUT', '/cases/$caseId/claimants', user: 2, body: {'member_ids': []}))
            .status,
        404,
      );
    });

    test('after filing it can no longer be changed, but the Gram Sabha reads it', () async {
      await rig.call('PUT', '/cases/$caseId/claimants', user: 1, body: {'member_ids': [ids[0]]});
      await rig.call('POST', '/cases/$caseId/submit', user: 1);
      final e = await rig.fails('PUT', '/cases/$caseId/claimants',
          user: 1, body: {'member_ids': []});
      _expectError(e, 409, 'CASE_NOT_EDITABLE', key: 'case.not_editable');
      expect(e.details['state'], 'gs_review');
      final gsView = await rig.call('GET', '/cases/$caseId/claimants', user: 3) as List;
      expect(gsView.single['gs_member_id'], ids[0]);
      // the Gram Sabha is not the claimant
      expect(
        (await rig.fails('PUT', '/cases/$caseId/claimants', user: 3, body: {'member_ids': []}))
            .error,
        'ONLY_CLAIMANT_CAN_EDIT',
      );
    });
  });

  group('letters', () {
    late DemoHarness h;
    late String villager;
    late String gs;
    late String sdo;
    const base = '/villages/${DemoAccounts.villageId}/letters';

    setUp(() async {
      h = DemoHarness();
      villager = await h.login('9000000001');
      gs = await h.login('9000000003');
      sdo = await h.login('9000000005');
    });
    tearDown(() => h.dispose());

    Map<String, dynamic> letter({String template = 'g5_maps_request', Object? caseId}) => {
          'template': template,
          'addressee': ' Tahsildar, Jawhar ',
          'subject': 'Maps of the village forest',
          if (caseId != null) 'case_id': caseId,
        };

    test('the Gram Sabha drafts a letter', () async {
      final out = await h.call('POST', base, token: gs, body: {
        ...letter(template: 'g6_records_request'),
        'body': 'Please send the records.',
        'records_requested': [' Khasra ', 'Gazette'],
      }) as Map;
      expect(out['template'], 'g6_records_request');
      expect(out['addressee'], 'Tahsildar, Jawhar');
      expect(out['body'], 'Please send the records.');
      expect(out['records_requested'], ['Khasra', 'Gazette']);
      expect(out['case_id'], isNull);
      expect(out['dispatched_on'], isNull);
      expect(out['reminder_on'], isNull);
      expect(out['reminder_due'], isFalse);
      expect(out['response_received_on'], isNull);
      expect(out['created_at'], isNotNull);
      expect(out.keys.toSet(), {
        'id', 'template', 'addressee', 'subject', 'body', 'case_id', 'neighbour_village',
        'records_requested', 'dispatched_on', 'reminder_on', 'reminder_due',
        'response_received_on', 'outcome', 'created_at', //
      });
    });

    test('only the Gram Sabha writes; the villager and the SDO may read', () async {
      for (final token in [villager, sdo]) {
        final e = await h.fails('POST', base, token: token, body: letter());
        expect(e.statusCode, 403);
      }
      await h.call('POST', base, token: gs, body: letter());
      expect(await h.call('GET', base, token: villager), hasLength(1));
      expect(await h.call('GET', base, token: sdo), hasLength(1));
    });

    test('a G2 to an adjoining Gram Sabha names the neighbour', () async {
      final e = await h.fails('POST', base,
          token: gs, body: letter(template: 'g2_intimation_adjoining'));
      expect(e.statusCode, 422);
      expect(e.error, 'NEIGHBOUR_VILLAGE_REQUIRED');
      expect(e.messageKey, 'letter.neighbour_village_required');
      final ok = await h.call('POST', base,
          token: gs,
          body: {...letter(template: 'g2_intimation_adjoining'), 'neighbour_village': 'Kasara'})
          as Map;
      expect(ok['neighbour_village'], 'Kasara');
    });

    test('validation: template, addressee and subject', () async {
      final e = await h.fails('POST', base,
          token: gs, body: {'template': 'g99', 'addressee': '', 'records_requested': 'x'});
      expect(e.statusCode, 422);
      expect(e.error, 'VALIDATION_ERROR');
      final fields = (e.details!['errors'] as List).map((x) => (x['loc'] as List).last).toSet();
      expect(fields, {'template', 'addressee', 'subject', 'records_requested'});
    });

    test('a letter about a case of this village; not one that is not', () async {
      final c = await h.call('POST', '/villages/${DemoAccounts.villageId}/cases',
          token: villager, body: {'claim_type': 'ifr'}) as Map;
      final ok = await h.call('POST', base, token: gs, body: letter(caseId: c['id'])) as Map;
      expect(ok['case_id'], c['id']);
      final e = await h.fails('POST', base,
          token: gs, body: letter(caseId: '00000000-0000-4000-8000-000000000099'));
      expect(e.statusCode, 422);
      expect(e.error, 'CASE_NOT_IN_VILLAGE');
      // filter the list by case and by template
      await h.call('POST', base, token: gs, body: letter(template: 'g7_site_visit'));
      expect(await h.call('GET', '$base?case_id=${c['id']}', token: gs), hasLength(1));
      expect(await h.call('GET', '$base?template=g7_site_visit', token: gs), hasLength(1));
      expect(await h.call('GET', base, token: gs), hasLength(2));
      expect((await h.fails('GET', '$base?template=nope', token: gs)).statusCode, 422);
    });

    test('dispatch sets the reminder date; the reminder falls due after 30 days', () async {
      final l = await h.call('POST', base, token: gs, body: letter()) as Map;
      final out = await h.call('POST', '/letters/${l['id']}/dispatch',
          token: gs, body: {'dispatched_on': '2026-10-14'}) as Map;
      expect(out['dispatched_on'], '2026-10-14');
      expect(out['reminder_on'], '2026-11-13');
      expect(out['reminder_due'], isFalse);
      h.advance(const Duration(days: 30));
      final list = await h.call('GET', base, token: gs) as List;
      expect(list.single['reminder_due'], isTrue);
      final custom = await h.call('POST', '/letters/${l['id']}/dispatch',
          token: gs, body: {'dispatched_on': '2026-10-14', 'reminder_after_days': 7}) as Map;
      expect(custom['reminder_on'], '2026-10-21');
    });

    test('dispatch: validation, and the Gram Sabha only', () async {
      final l = await h.call('POST', base, token: gs, body: letter()) as Map;
      final bad = await h.fails('POST', '/letters/${l['id']}/dispatch',
          token: gs, body: {'dispatched_on': '2026-10-14', 'reminder_after_days': 0});
      expect(bad.statusCode, 422);
      expect(bad.error, 'VALIDATION_ERROR');
      for (final token in [villager, sdo]) {
        final e = await h.fails('POST', '/letters/${l['id']}/dispatch',
            token: token, body: {'dispatched_on': '2026-10-14'});
        // the villager and the SDO see the village, so the letter exists for them: refused
        expect(e.statusCode, 403);
        expect(e.error, 'FORBIDDEN');
      }
      final missing = await h.fails('POST', '/letters/00000000-0000-4000-8000-000000000099/dispatch',
          token: gs, body: {'dispatched_on': '2026-10-14'});
      expect(missing.statusCode, 404);
      expect(missing.error, 'LETTER_NOT_FOUND');
    });

    test('a reply, only after the letter went out', () async {
      final l = await h.call('POST', base, token: gs, body: letter()) as Map;
      final early = await h.fails('POST', '/letters/${l['id']}/response',
          token: gs, body: {'received_on': '2026-10-20', 'outcome': 'Maps sent'});
      expect(early.statusCode, 422);
      expect(early.error, 'RESPONSE_BEFORE_DISPATCH');
      expect(early.messageKey, 'letter.response_before_dispatch');
      await h.call('POST', '/letters/${l['id']}/dispatch',
          token: gs, body: {'dispatched_on': '2026-10-14'});
      final before = await h.fails('POST', '/letters/${l['id']}/response',
          token: gs, body: {'received_on': '2026-10-13', 'outcome': 'Maps sent'});
      expect(before.error, 'RESPONSE_BEFORE_DISPATCH');
      final out = await h.call('POST', '/letters/${l['id']}/response',
          token: gs, body: {'received_on': '2026-10-20', 'outcome': ' Maps sent '}) as Map;
      expect(out['response_received_on'], '2026-10-20');
      expect(out['outcome'], 'Maps sent');
      // answered: no reminder is due any more
      h.advance(const Duration(days: 60));
      expect((await h.call('GET', base, token: gs) as List).single['reminder_due'], isFalse);
      expect((await h.fails('POST', '/letters/${l['id']}/response',
              token: villager, body: {'received_on': '2026-10-20', 'outcome': 'x'}))
          .statusCode, 403);
    });

    test('someone with no role in the village does not find its letters', () async {
      final admin = await h.login('9000000004');
      final l = await h.call('POST', base, token: gs, body: letter()) as Map;
      final e = await h.fails('POST', '/letters/${l['id']}/dispatch',
          token: admin, body: {'dispatched_on': '2026-10-14'});
      expect(e.statusCode, 404);
      expect(e.error, 'LETTER_NOT_FOUND');
    });
  });

  group('post-title follow-up and timeline', () {
    late _Rig rig;
    late String caseId;

    /// A case of the village moved to [state]; when the title is issued the event is on record.
    void setState(String state, {String at = '2026-10-14T06:30:00.000Z'}) {
      final c = rig.db.byId('claim_case', caseId)!;
      c['state'] = state;
      c['reached_stage'] = DemoCases.stage[state] ?? 0;
      if (state == CaseStates.titleIssued) {
        rig.db.add('workflow_event', {
          'case_id': caseId,
          'action': 'approve',
          'from_state': 'district_review',
          'to_state': 'title_issued',
          'actor_user_id': null,
          'actor_role': null,
          'actor_name': 'District',
          'remarks': null,
          'created_at': at,
        });
      }
    }

    Map<String, dynamic> media(int user) => rig.db.add('media', {
          'sha256': 'a' * 64,
          'mime': 'application/pdf',
          'size_bytes': 10,
          'storage_key': 'k',
          'uploaded_by_user_id': DemoAccounts.userIdFor(user),
        });

    setUp(() async {
      rig = _Rig();
      final c = await rig.call('POST', '/villages/${_Rig.village}/cases',
          user: 1, body: {'claim_type': 'ifr'}) as Map;
      caseId = c['id'] as String;
    });

    test('before the title: nothing to record, and no one may', () async {
      final out = await rig.call('GET', '/cases/$caseId/post-title', user: 1) as Map;
      expect(out['case_id'], caseId);
      expect(out['title_issued_on'], isNull);
      expect(out['record_update_due_on'], isNull);
      expect(out['survey_pending'], isFalse);
      expect(out['can_close'], isFalse);
      expect(out['missing'], ['certified_copy', 'record_entry']);
      expect(out['closed_on'], isNull);
      expect(out.keys.toSet(), {
        'certified_copy_media_id', 'certified_copy_on', 'survey_letter_id', 'survey_done_on',
        'record_entry_on', 'record_entry_ref', 'record_entry_media_id', 'case_id',
        'title_issued_on', 'record_update_due_on', 'survey_pending', 'can_close', 'missing',
        'closed_on', //
      });
      setState(CaseStates.gsReview);
      final e = await rig.fails('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'record_entry_on': '2026-10-14'});
      _expectError(e, 409, 'TITLE_NOT_ISSUED', key: 'followup.title_not_issued');
      expect((await rig.fails('POST', '/cases/$caseId/close', user: 3)).error, 'TITLE_NOT_ISSUED');
    });

    test('the villager cannot record; the Gram Sabha can; strangers see nothing', () async {
      setState(CaseStates.titleIssued);
      final e = await rig.fails('PUT', '/cases/$caseId/post-title',
          user: 1, body: {'record_entry_on': '2026-10-14'});
      _expectError(e, 403, 'NOT_YOUR_LEVEL', key: 'workflow.not_your_level');
      expect((await rig.fails('POST', '/cases/$caseId/close', user: 1)).error, 'NOT_YOUR_LEVEL');
      expect((await rig.fails('GET', '/cases/$caseId/post-title', user: 2)).status, 404);
    });

    test('record, then close once the certified copy and the record entry are in', () async {
      setState(CaseStates.titleIssued);
      final get = await rig.call('GET', '/cases/$caseId/post-title', user: 3) as Map;
      expect(get['title_issued_on'], '2026-10-14');
      expect(get['record_update_due_on'], '2027-01-14');
      expect(get['survey_pending'], isTrue);

      final cannot = await rig.fails('POST', '/cases/$caseId/close', user: 3);
      _expectError(cannot, 409, 'CANNOT_CLOSE', key: 'followup.cannot_close', rule: 'Rule 8(i), 12A(9)');
      expect(cannot.details['missing'], ['certified_copy', 'record_entry']);

      final copy = media(3);
      final first = await rig.call('PUT', '/cases/$caseId/post-title', user: 3, body: {
        'certified_copy_media_id': copy['id'],
        'certified_copy_on': '2026-10-20',
        'record_entry_ref': ' 7/12 entry 55 ',
      }) as Map;
      expect(first['certified_copy_media_id'], copy['id']);
      expect(first['certified_copy_on'], '2026-10-20');
      expect(first['record_entry_ref'], '7/12 entry 55');
      expect(first['missing'], ['record_entry']);
      expect(first['can_close'], isFalse);

      final second = await rig.call('PUT', '/cases/$caseId/post-title',
          user: 5, body: {'record_entry_on': '2026-12-01', 'survey_done_on': '2026-11-20'}) as Map;
      expect(second['missing'], isEmpty);
      expect(second['can_close'], isTrue);
      expect(second['survey_pending'], isFalse);
      expect(second['certified_copy_media_id'], copy['id']); // earlier values stay

      final closed = await rig.call('POST', '/cases/$caseId/close', user: 3) as Map;
      expect(closed['closed_on'], '2026-10-14');
      expect(closed['can_close'], isTrue);

      // closing again changes nothing, even on another day
      rig.advance(const Duration(days: 3));
      expect((await rig.call('POST', '/cases/$caseId/close', user: 3) as Map)['closed_on'],
          '2026-10-14');
      final locked = await rig.fails('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'record_entry_ref': 'x'});
      _expectError(locked, 409, 'CASE_CLOSED', key: 'followup.closed');
      // the claimant can read it
      expect((await rig.call('GET', '/cases/$caseId/post-title', user: 1) as Map)['closed_on'],
          '2026-10-14');
    });

    test('a file must be the caller\'s own, a letter must be of this village', () async {
      setState(CaseStates.titleIssued);
      final theirs = media(1);
      final e = await rig.fails('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'certified_copy_media_id': theirs['id']});
      _expectError(e, 422, 'MEDIA_NOT_YOURS', key: 'evidence.media_not_yours');
      final unknown = await rig.fails('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'record_entry_media_id': '00000000-0000-4000-8000-000000000099'});
      expect(unknown.error, 'MEDIA_NOT_YOURS');
      final badLetter = await rig.fails('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'survey_letter_id': '00000000-0000-4000-8000-000000000099'});
      _expectError(badLetter, 422, 'LETTER_NOT_IN_VILLAGE', key: 'letter.not_found');

      final l = await rig.call('POST', '/villages/${_Rig.village}/letters', user: 3, body: {
        'template': 'g18_survey_request',
        'addressee': 'Survey office',
        'subject': 'Survey of the titled land',
      }) as Map;
      final ok = await rig.call('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'survey_letter_id': l['id']}) as Map;
      expect(ok['survey_letter_id'], l['id']);
      // explicitly sending null clears a field
      final cleared = await rig.call('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'survey_letter_id': null}) as Map;
      expect(cleared['survey_letter_id'], isNull);
    });

    test('validation of the follow-up fields', () async {
      setState(CaseStates.titleIssued);
      final e = await rig.fails('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'record_entry_on': 'soon', 'certified_copy_media_id': 'abc'});
      expect(e.status, 422);
      expect(e.error, 'VALIDATION_ERROR');
      expect((e.details['errors'] as List).map((x) => (x['loc'] as List).last).toSet(),
          {'record_entry_on', 'certified_copy_media_id'});
    });

    test('timeline: the claim window, the petition, a dispute and the record entry', () async {
      // the case was filed within an open call
      final call = await rig.call('POST', '/villages/${_Rig.village}/claim-calls',
          user: 3, body: {'called_on': '2026-10-01', 'place_of_filing': 'GP office'}) as Map;
      expect(await rig.call('GET', '/cases/$caseId/timeline', user: 1), isEmpty);
      final c = rig.db.byId('claim_case', caseId)!;
      c['claim_call_id'] = call['id'];

      var line = await rig.call('GET', '/cases/$caseId/timeline', user: 1) as List;
      expect(line.single, {
        'kind': 'claim_window',
        'rule': 'Rule 11(1)(a)',
        'starts_on': '2026-10-01',
        'due_on': '2027-01-01',
        'status': 'running',
        'days_remaining': 79,
        'next_alert_on': null,
      });
      c['filed_within_window'] = true;
      c['acknowledged_on'] = '2026-10-05';
      line = await rig.call('GET', '/cases/$caseId/timeline', user: 1) as List;
      expect(line.single['status'], 'met');

      // a Gram Sabha resolution starts the 60-day petition period, with reminders
      setState(CaseStates.gsReview);
      rig.db.add('resolution', {
        'case_id': caseId,
        'created_at': '2026-09-24T10:00:00.000Z',
        'supersedes_id': null,
      });
      line = await rig.call('GET', '/cases/$caseId/timeline', user: 3) as List;
      expect(line.map((e) => e['kind']), ['claim_window', 'petition_against_resolution']);
      expect(line[1], {
        'kind': 'petition_against_resolution',
        'rule': 'Sec 6(2), Rule 14(1)',
        'starts_on': '2026-09-24',
        'due_on': '2026-11-23',
        'status': 'running',
        'days_remaining': 40,
        'next_alert_on': '2026-10-24', // day 30
      });

      // a corrected resolution replaces the earlier one
      final firstRes = rig.db.table('resolution').first;
      rig.db.add('resolution', {
        'case_id': caseId,
        'created_at': '2026-10-10T10:00:00.000Z',
        'supersedes_id': firstRes['id'],
      });
      line = await rig.call('GET', '/cases/$caseId/timeline', user: 3) as List;
      expect(line[1]['starts_on'], '2026-10-10');

      // an overlap with a neighbour: 30 days to settle between the Gram Sabhas
      rig.db.add('dispute', {
        'case_id': '00000000-0000-4000-8000-0000000000bb',
        'neighbour_case_id': caseId,
        'overlap_ha': 0.5,
        'detected_on': '2026-10-01',
        'joint_meeting_on': null,
        'sdlc_referral_on': null,
      });
      rig.db.add('dispute', {
        'case_id': caseId,
        'neighbour_case_id': '00000000-0000-4000-8000-0000000000cc',
        'overlap_ha': 0,
        'detected_on': '2026-10-01',
      }); // no overlap any more: no clock
      line = await rig.call('GET', '/cases/$caseId/timeline', user: 3) as List;
      final mutual = line.firstWhere((e) => e['kind'] == 'mutual_solution');
      expect(mutual['rule'], 'Rule 14(7)');
      expect(mutual['due_on'], '2026-10-31');
      expect(mutual['status'], 'running');
      expect(line.where((e) => e['kind'] == 'mutual_solution'), hasLength(1));
      rig.db.table('dispute').first['joint_meeting_on'] = '2026-10-12';
      line = await rig.call('GET', '/cases/$caseId/timeline', user: 3) as List;
      expect(line.firstWhere((e) => e['kind'] == 'mutual_solution')['status'], 'met');

      // after the title: three months to enter it in the record of rights
      setState(CaseStates.titleIssued);
      line = await rig.call('GET', '/cases/$caseId/timeline', user: 3) as List;
      final record = line.last;
      expect(record, {
        'kind': 'record_update',
        'rule': 'Rule 12A(9)',
        'starts_on': '2026-10-14',
        'due_on': '2027-01-14',
        'status': 'running',
        'days_remaining': 92,
        'next_alert_on': null,
      });
      await rig.call('PUT', '/cases/$caseId/post-title',
          user: 3, body: {'record_entry_on': '2026-11-01'});
      line = await rig.call('GET', '/cases/$caseId/timeline', user: 3) as List;
      expect(line.last['status'], 'met');
    });

    test('timeline: an overdue claim window; unseen cases are 404', () async {
      final call = await rig.call('POST', '/villages/${_Rig.village}/claim-calls',
          user: 3, body: {'called_on': '2026-05-01', 'place_of_filing': 'GP office'}) as Map;
      rig.db.byId('claim_case', caseId)!['claim_call_id'] = call['id'];
      final line = await rig.call('GET', '/cases/$caseId/timeline', user: 1) as List;
      expect(line.single['status'], 'overdue');
      expect(line.single['due_on'], '2026-08-01');
      expect(line.single['days_remaining'], -74);
      expect((await rig.fails('GET', '/cases/$caseId/timeline', user: 2)).error, 'CASE_NOT_FOUND');
      expect((await rig.fails('GET', '/cases/$caseId/timeline', user: 3)).error, 'CASE_NOT_FOUND');
    });
  });

  test('every route asks to be signed in', () async {
    final h = DemoHarness();
    addTearDown(h.dispose);
    const v = DemoAccounts.villageId;
    const id = '00000000-0000-4000-8000-000000000099';
    for (final (method, path) in [
      ('GET', '/villages/$v/claim-calls'),
      ('GET', '/villages/$v/claim-calls/current'),
      ('GET', '/villages/$v/letters'),
      ('POST', '/letters/$id/dispatch'),
      ('GET', '/villages/$v'),
      ('GET', '/villages/$v/hamlets'),
      ('GET', '/villages/$v/frc'),
      ('GET', '/villages/$v/frc/history'),
      ('GET', '/cases/$id/claimants'),
      ('GET', '/cases/$id/post-title'),
      ('POST', '/cases/$id/close'),
      ('GET', '/cases/$id/timeline'),
    ]) {
      final ApiException e = await h.fails(method, path, body: {});
      expect(e.statusCode, 401, reason: '$method $path');
    }
  });
}
