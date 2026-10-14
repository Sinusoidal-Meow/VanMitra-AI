import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';

import 'demo_support.dart';

const String _v = DemoAccounts.villageId;

void main() {
  late DemoHarness h;
  setUp(() => h = DemoHarness());
  tearDown(() => h.dispose());

  group('sign in and accounts', () {
    test('every seeded login works with PIN 123456 and has the right role', () async {
      final expected = {
        '9000000001': 'villager',
        '9000000002': 'villager',
        '9000000003': 'gram_sabha',
        '9000000005': 'sdo',
      };
      for (final e in expected.entries) {
        final me = await h.call('GET', '/me', token: await h.login(e.key));
        expect((me['roles'] as List).single['role'], e.value, reason: e.key);
      }
      final admin = await h.call('GET', '/me', token: await h.login('9000000004'));
      expect(admin['is_admin'], isTrue);
      expect(admin['roles'], isEmpty);
    });

    test('the village user is in Ozhar, the SDO covers the taluka', () async {
      final me = await h.call('GET', '/me', token: await h.login('9000000001'));
      final role = (me['roles'] as List).single as Map;
      expect(role['village_id'], _v);
      expect(role['village_name_en'], 'Ozhar');
      expect(role['level'], 'village');
      final sdo = await h.call('GET', '/me', token: await h.login('9000000005'));
      final sdoRole = (sdo['roles'] as List).single as Map;
      expect(sdoRole['level'], 'subdivision');
      expect(sdoRole['taluka'], 'Jawhar');
      expect(sdoRole['village_id'], isNull);
    });

    test('a wrong PIN, an unknown phone and a malformed phone are refused', () async {
      final wrongPin = await h.fails('POST', '/auth/login',
          body: {'phone': '9000000001', 'pin': '000000'});
      expect(wrongPin.statusCode, 401);
      final unknown = await h.fails('POST', '/auth/login',
          body: {'phone': '9999999999', 'pin': '123456'});
      expect(unknown.statusCode, 401);
      final malformed =
          await h.fails('POST', '/auth/login', body: {'phone': '123', 'pin': '123456'});
      expect(malformed.statusCode, 422);
    });

    test('no token is 401', () async {
      expect((await h.fails('GET', '/me')).statusCode, 401);
      expect((await h.fails('GET', '/me', token: 'garbage')).statusCode, 401);
    });

    test('a new village user can register, sign in, and is a villager of the village', () async {
      final t = await h.call('POST', '/auth/register', body: {
        'name': 'Sita Bhoye',
        'phone': '9876543210',
        'pin': '246810',
        'village_id': _v,
      });
      expect(t['access_token'], isNotEmpty);
      final again = await h.login('9876543210', pin: '246810');
      final me = await h.call('GET', '/me', token: again);
      expect(me['name'], 'Sita Bhoye');
      expect((me['roles'] as List).single['role'], 'villager');
      final twice = await h.fails('POST', '/auth/register', body: {
        'name': 'X',
        'phone': '9876543210',
        'pin': '246810',
        'village_id': _v,
      });
      expect(twice.statusCode, 409);
    });

    test('registration checks the phone, PIN and village', () async {
      Future<int> status(Map<String, dynamic> b) async =>
          (await h.fails('POST', '/auth/register', body: b)).statusCode;
      expect(await status({'name': 'A', 'phone': '12345', 'pin': '123456', 'village_id': _v}), 422);
      expect(
          await status({'name': 'A', 'phone': '9876543210', 'pin': '12', 'village_id': _v}), 422);
      expect(
          await status({'name': '', 'phone': '9876543210', 'pin': '123456', 'village_id': _v}),
          422);
      expect(
          await status(
              {'name': 'A', 'phone': '9876543210', 'pin': '123456', 'village_id': 'nope'}),
          422);
    });

    test('the public village list needs no sign-in', () async {
      final villages = await h.call('GET', '/public/villages') as List;
      expect(villages.single['name_en'], 'Ozhar');
    });

    test('only the admin creates logins, and not district roles', () async {
      final villager = await h.login('9000000001');
      final admin = await h.login('9000000004');
      final body = {
        'name': 'New GS',
        'phone': '9111111111',
        'pin': '123456',
        'role': 'gram_sabha',
        'village_id': _v,
      };
      final denied = await h.fails('POST', '/admin/users', token: villager, body: body);
      expect(denied.statusCode, 403);
      final made = await h.call('POST', '/admin/users', token: admin, body: body);
      expect(made['role'], 'gram_sabha');
      final district = await h.fails('POST', '/admin/users',
          token: admin, body: {...body, 'phone': '9222222222', 'role': 'collector'});
      expect(district.statusCode, 422);
      final list = await h.call('GET', '/admin/users', token: admin) as List;
      expect(list.length, 5); // villager x2, gram sabha, sdo, and the new gram sabha
    });
  });

  group('cases and the claim path', () {
    Future<Map> open(String token, String type) async =>
        await h.call('POST', '/villages/$_v/cases', token: token, body: {'claim_type': type})
            as Map;

    test('a village user opens Forms A, B and C; the Gram Sabha opens B and C, not A', () async {
      final villager = await h.login('9000000001');
      final gs = await h.login('9000000003');
      expect((await open(villager, 'ifr'))['form'], 'A');
      expect((await open(villager, 'cr'))['form'], 'B');
      expect((await open(villager, 'cfr'))['form'], 'C'); // allowed while testing
      expect((await open(gs, 'cr'))['form'], 'B');
      final denied =
          await h.fails('POST', '/villages/$_v/cases', token: gs, body: {'claim_type': 'ifr'});
      expect(denied.statusCode, 403);
      expect(denied.error, 'NOT_ALLOWED_TO_OPEN_FORM');
    });

    test('a new case is a draft with the right buttons and shows in my list', () async {
      final villager = await h.login('9000000001');
      final c = await open(villager, 'ifr');
      expect(c['state'], 'draft');
      expect(c['is_mine'], isTrue);
      expect(c['allowed_actions'], ['submit']);
      expect(c['returned'], isNull);
      expect(c['claimant_label'], 'Gram Sabha, Ozhar');
      final mine = await h.call('GET', '/cases/mine', token: villager) as List;
      expect(mine.single['id'], c['id']);
      expect(await h.call('GET', '/cases/mine', token: await h.login('9000000002')), isEmpty);
    });

    test('nobody else sees a draft; the claimant and, later, the officers do', () async {
      final villager = await h.login('9000000001');
      final gs = await h.login('9000000003');
      final other = await h.login('9000000002');
      final sdo = await h.login('9000000005');
      final id = (await open(villager, 'cr'))['id'];
      expect((await h.fails('GET', '/cases/$id', token: gs)).statusCode, 404);
      expect((await h.fails('GET', '/cases/$id', token: other)).statusCode, 404);
      expect(await h.call('GET', '/villages/$_v/cases', token: gs), isEmpty);
      await h.call('POST', '/cases/$id/submit', token: villager);
      expect((await h.call('GET', '/cases/$id', token: gs))['state'], 'gs_review');
      expect((await h.fails('GET', '/cases/$id', token: other)).statusCode, 404);
      // not at the SDO yet
      expect((await h.fails('GET', '/cases/$id', token: sdo)).statusCode, 404);
    });

    test('submit, Gram Sabha approves, SDO approves, handed to the district', () async {
      final villager = await h.login('9000000001');
      final gs = await h.login('9000000003');
      final sdo = await h.login('9000000005');
      final id = (await open(villager, 'ifr'))['id'];

      final filed = await h.call('POST', '/cases/$id/submit', token: villager);
      expect(filed['state'], 'gs_review');
      expect(filed['allowed_actions'], isEmpty); // the claimant can only wait

      final gsView = await h.call('GET', '/cases/$id', token: gs);
      expect(gsView['allowed_actions'], containsAll(['approve', 'return', 'reject']));
      expect(((await h.call('GET', '/review/queue', token: gs)) as List).single['id'], id);

      final atSdo = await h.call('POST', '/cases/$id/approve', token: gs);
      expect(atSdo['state'], 'sdo_review');
      expect(await h.call('GET', '/review/queue', token: gs), isEmpty);
      expect(((await h.call('GET', '/review/queue', token: sdo)) as List).single['id'], id);

      final atDistrict = await h.call('POST', '/cases/$id/approve', token: sdo);
      expect(atDistrict['state'], 'district_review');
      final again = await h.fails('POST', '/cases/$id/approve', token: sdo);
      expect(again.error, 'HANDED_TO_DISTRICT');

      final history = await h.call('GET', '/cases/$id/history', token: villager) as List;
      expect(history.map((e) => e['action']), ['submit', 'approve', 'approve']);
      expect(history.map((e) => e['actor_role']), ['villager', 'gram_sabha', 'sdo']);
      expect(history.last['to_state'], 'district_review');
    });

    test('only the right level acts; the claimant cannot approve their own claim', () async {
      final villager = await h.login('9000000001');
      final sdo = await h.login('9000000005');
      final id = (await open(villager, 'ifr'))['id'];
      await h.call('POST', '/cases/$id/submit', token: villager);
      final self = await h.fails('POST', '/cases/$id/approve', token: villager);
      expect(self.error, 'NOT_YOUR_LEVEL');
      // the SDO cannot even see it yet
      expect((await h.fails('POST', '/cases/$id/approve', token: sdo)).statusCode, 404);
    });

    test('return needs written remarks, gives 60 days, and the window closes', () async {
      final villager = await h.login('9000000001');
      final gs = await h.login('9000000003');
      final id = (await open(villager, 'ifr'))['id'];
      await h.call('POST', '/cases/$id/submit', token: villager);

      final short = await h.fails('POST', '/cases/$id/return', token: gs, body: {'remarks': 'no'});
      expect(short.statusCode, 422);
      expect(short.error, 'REMARKS_REQUIRED');

      final back = await h.call('POST', '/cases/$id/return',
          token: gs, body: {'remarks': 'Please add the survey number.'});
      expect(back['state'], 'draft');
      final mine = await h.call('GET', '/cases/$id', token: villager);
      expect(mine['allowed_actions'], ['submit']);
      expect(mine['returned']['by_role'], 'gram_sabha');
      expect(mine['returned']['remarks'], 'Please add the survey number.');
      expect(mine['returned']['days_left'], 60);

      h.advance(const Duration(days: 61)); // 61 days later the window has closed
      final late = await h.call('GET', '/cases/$id', token: villager);
      expect(late['returned']['days_left'], 0);
      expect(late['allowed_actions'], isEmpty);
      final tooLate = await h.fails('POST', '/cases/$id/submit', token: villager);
      expect(tooLate.error, 'RESUBMIT_WINDOW_PASSED');
    });

    test('a returned claim resubmitted in time starts again at the Gram Sabha', () async {
      final villager = await h.login('9000000001');
      final gs = await h.login('9000000003');
      final id = (await open(villager, 'ifr'))['id'];
      await h.call('POST', '/cases/$id/submit', token: villager);
      await h.call('POST', '/cases/$id/return', token: gs, body: {'remarks': 'Fix the address.'});
      h.advance(const Duration(days: 10));
      expect((await h.call('POST', '/cases/$id/submit', token: villager))['state'], 'gs_review');
      final history = await h.call('GET', '/cases/$id/history', token: villager) as List;
      expect(history.map((e) => e['action']), ['submit', 'return', 'submit']);
    });

    test('reject needs reasons (Rule 12A(7)) and is final', () async {
      final villager = await h.login('9000000001');
      final gs = await h.login('9000000003');
      final id = (await open(villager, 'ifr'))['id'];
      await h.call('POST', '/cases/$id/submit', token: villager);
      final noReason = await h.fails('POST', '/cases/$id/reject', token: gs, body: {'remarks': ''});
      expect(noReason.rule, 'Rule 12A(7)');
      final rejected = await h.call('POST', '/cases/$id/reject',
          token: gs, body: {'remarks': 'The land is outside the forest area.'});
      expect(rejected['state'], 'rejected');
      expect((await h.fails('POST', '/cases/$id/approve', token: gs)).error, 'CASE_CLOSED');
    });

    test('a submitted claim cannot be submitted again', () async {
      final villager = await h.login('9000000001');
      final id = (await open(villager, 'ifr'))['id'];
      await h.call('POST', '/cases/$id/submit', token: villager);
      expect((await h.fails('POST', '/cases/$id/submit', token: villager)).error, 'NOT_A_DRAFT');
    });

    test('the village list shows what the caller may see, newest first', () async {
      final villager = await h.login('9000000001');
      final gs = await h.login('9000000003');
      final a = (await open(villager, 'ifr'))['id'];
      h.advance(const Duration(minutes: 1));
      final b = (await open(villager, 'cr'))['id'];
      await h.call('POST', '/cases/$a/submit', token: villager);
      final list = await h.call('GET', '/villages/$_v/cases', token: villager) as List;
      expect(list.map((c) => c['id']), [b, a]);
      final seen = await h.call('GET', '/villages/$_v/cases', token: gs) as List;
      expect(seen.single['id'], a); // only the filed one
    });

    test('an unknown village is a 404', () async {
      final villager = await h.login('9000000001');
      final r = await h.fails('GET', '/villages/does-not-exist/cases', token: villager);
      expect(r.statusCode, 404);
    });
  });
}
