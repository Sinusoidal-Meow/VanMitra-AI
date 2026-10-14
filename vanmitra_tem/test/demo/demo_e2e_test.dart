import 'package:flutter_test/flutter_test.dart';
import 'package:vanmitra_ai/demo/core/demo_accounts.dart';

import 'demo_support.dart';

const String _v = DemoAccounts.villageId;

void main() {
  late DemoHarness h;
  tearDown(() => h.dispose());

  group('the sample claims every login finds on a fresh phone', () {
    setUp(() => h = DemoHarness(sampleClaims: true));

    test('the village user has four claims in four situations', () async {
      final villager = await h.login('9000000001');
      final mine = await h.call('GET', '/cases/mine', token: villager) as List;
      expect(mine, hasLength(4));
      final states = mine.map((c) => c['state']).toList();
      expect(states.where((s) => s == 'draft'), hasLength(2)); // one sent back, one in progress
      expect(states, contains('gs_review'));
      expect(states, contains('sdo_review'));
      final sentBack = mine.firstWhere((c) => c['returned'] != null) as Map;
      expect(sentBack['returned']['by_role'], 'gram_sabha');
      expect(sentBack['returned']['days_left'], 60);
      expect(sentBack['allowed_actions'], ['submit']);
    });

    test('the second village user sees only their own claim', () async {
      final mine = await h.call('GET', '/cases/mine', token: await h.login('9000000002')) as List;
      expect(mine, hasLength(1));
      expect(mine.single['claimant_label'], 'Meena Pawar, Raju Pawar');
    });

    test('the Gram Sabha has a claim waiting, and a Form C of its own', () async {
      final gs = await h.login('9000000003');
      final queue = await h.call('GET', '/review/queue', token: gs) as List;
      expect(queue.single['form'], 'B');
      final mine = await h.call('GET', '/cases/mine', token: gs) as List;
      expect(mine.single['form'], 'C');
      final form = await h.call('GET', '/cases/${mine.single['id']}/form-c', token: gs);
      expect(form['completeness']['done'], lessThan(form['completeness']['total']));
    });

    test('the SDO has the claim the Gram Sabha approved', () async {
      final sdo = await h.login('9000000005');
      final queue = await h.call('GET', '/review/queue', token: sdo) as List;
      expect(queue.single['form'], 'A');
      expect(queue.single['state'], 'sdo_review');
      expect(queue.single['claimant_label'], 'Ramesh Gavit, Sunita Gavit');
    });

    test('the seeded Form A is complete, and Form A and B reach the district', () async {
      final villager = await h.login('9000000001');
      final gs = await h.login('9000000003');
      final sdo = await h.login('9000000005');
      final fa = (await h.call('GET', '/review/queue', token: sdo) as List).single;
      final form = await h.call('GET', '/cases/${fa['id']}/form-a', token: sdo);
      expect(form['completeness']['done'], form['completeness']['total']);

      final b = (await h.call('GET', '/review/queue', token: gs) as List).single;
      await h.call('POST', '/cases/${b['id']}/approve', token: gs);
      for (final c in await h.call('GET', '/review/queue', token: sdo) as List) {
        await h.call('POST', '/cases/${c['id']}/approve', token: sdo);
      }
      final mine = await h.call('GET', '/cases/mine', token: villager) as List;
      expect(mine.where((c) => c['state'] == 'district_review'), hasLength(2));
      final done = mine.firstWhere((c) => c['state'] == 'district_review') as Map;
      final title = await h.call('GET', '/cases/${done['id']}/title-draft', token: villager);
      expect(title['annexure'], isNotEmpty);
    });

    test('a sample claim can be corrected and sent again after being returned', () async {
      final villager = await h.login('9000000001');
      final mine = await h.call('GET', '/cases/mine', token: villager) as List;
      final sentBack = mine.firstWhere((c) => c['returned'] != null) as Map;
      final id = sentBack['id'];
      final form = await h.call('GET', '/cases/$id/form-a', token: villager);
      expect(form['editable'], isTrue);
      final again = await h.call('POST', '/cases/$id/submit', token: villager);
      expect(again['state'], 'gs_review');
    });
  });

  group('a new person from sign-up to the SDO', () {
    setUp(() => h = DemoHarness());

    test('register, file Form A, Gram Sabha and SDO approve, it reaches the district', () async {
      final t = await h.call('POST', '/auth/register', body: {
        'name': 'Sanskriti Patil',
        'phone': '9812345670',
        'pin': '135790',
        'village_id': _v,
      });
      final me = t['access_token'] as String;
      final gs = await h.login('9000000003');
      final sdo = await h.login('9000000005');

      final c = await h.call('POST', '/villages/$_v/cases', token: me, body: {'claim_type': 'ifr'});
      final id = c['id'];
      var form = await h.call('GET', '/cases/$id/form-a', token: me);
      expect(form['completeness']['done'], lessThan(form['completeness']['total']));

      await h.call('PUT', '/cases/$id/form-a', token: me, body: {
        'claimant_names': ['Sanskriti Patil'],
        'address': 'Ozhar',
        'is_scheduled_tribe': true,
        'is_otfd': false,
        'claims': {
          'self_cultivation': {'extent_ha': 0.9, 'details': 'Field near the river'},
        },
        'evidence': [
          {'rule_ref': '13(1)(a)', 'description': '7/12 extract'},
          {'rule_ref': '13(1)(i)', 'description': 'Elders statement'},
        ],
      });
      form = await h.call('GET', '/cases/$id/form-a', token: me);
      expect(form['completeness']['done'], form['completeness']['total']);
      expect((await h.call('GET', '/cases/mine', token: me) as List).single['claimant_label'],
          'Sanskriti Patil');

      await h.call('POST', '/cases/$id/submit', token: me);
      // the form is locked once filed
      final locked = await h.fails('PUT', '/cases/$id/form-a', token: me, body: {});
      expect(locked.statusCode, 409);
      // and the written acknowledgement was issued
      final ack = await h.call('GET', '/cases/$id/acknowledgement', token: me);
      expect(ack['serial'], isNotEmpty);

      await h.call('POST', '/cases/$id/approve', token: gs);
      await h.call('POST', '/cases/$id/approve', token: sdo);
      final done = await h.call('GET', '/cases/$id', token: me);
      expect(done['state'], 'district_review');
      final history = await h.call('GET', '/cases/$id/history', token: me) as List;
      expect(history.map((e) => e['actor_role']), ['villager', 'gram_sabha', 'sdo']);
      // the ledger of the village is intact after all of it
      final ledger = await h.call('GET', '/villages/$_v/ledger/verify', token: gs);
      expect(ledger['ok'], isTrue);
    });

    test('Form C: the Gram Sabha cannot approve it until the legal steps are done', () async {
      final gs = await h.login('9000000003');
      final sdo = await h.login('9000000005');
      final c = await h.call('POST', '/villages/$_v/cases', token: gs, body: {'claim_type': 'cfr'});
      final id = c['id'];
      await h.call('PUT', '/cases/$id/form-c', token: gs, body: {
        'area_description': 'Forest east of the village',
        'approx_area_ha': 100,
        'landmarks': [
          {'side': 'east', 'kind': 'stream', 'name': 'Stream'},
        ],
        'khasra_compartment_numbers': ['C-1'],
      });
      await h.call('POST', '/cases/$id/submit', token: gs);
      final blocked = await h.fails('POST', '/cases/$id/approve', token: gs);
      expect(blocked.statusCode, 409);
      expect(blocked.error, 'GS_PREREQUISITES_MISSING');
      expect((blocked.details!['missing'] as List), isNotEmpty);
      // the SDO cannot see it yet
      expect((await h.fails('GET', '/cases/$id', token: sdo)).statusCode, 404);
    });
  });
}
