import 'core/demo_accounts.dart';

/// A few SAMPLE claims so every login has something to open the first time (the Gram Sabha and
/// the SDO have claims waiting, the village user has a claim that was sent back, and so on).
///
/// They are made through the demo server's own routes, exactly as a person would make them, so
/// they obey every rule and every response is the real shape. All names are made up.
typedef DemoCall = Future<dynamic> Function(String method, String path,
    {Object? body, String? token});

class DemoSeedClaims {
  DemoSeedClaims._();

  static String _token(int n) => DemoAccounts.tokens(DemoAccounts.userIdFor(n))['access_token'] as String;

  static Future<void> run(DemoCall call) async {
    final villager = _token(1); // 9000000001
    final villager2 = _token(2); // 9000000002
    final gramSabha = _token(3); // 9000000003
    final sdo = _token(5); // 9000000005
    final village = DemoAccounts.villageId;

    Future<String> open(String token, String type) async =>
        ((await call('POST', '/villages/$village/cases', token: token, body: {'claim_type': type}))
            as Map)['id'] as String;
    Future<void> fill(String token, String id, String form, Map<String, dynamic> body) =>
        call('PUT', '/cases/$id/$form', token: token, body: body);
    Future<void> act(String token, String id, String action, {String? remarks}) => call(
          'POST',
          '/cases/$id/$action',
          token: token,
          body: remarks == null ? null : {'remarks': remarks},
        );

    // 1. A complete Form A, already approved by the Gram Sabha: waiting for the SDO.
    final a1 = await open(villager, 'ifr');
    await fill(villager, a1, 'form-a', _formA('Ramesh Gavit', 'Sunita Gavit', 1.2, 'Plot behind the school'));
    await act(villager, a1, 'submit');
    await act(gramSabha, a1, 'approve');

    // 2. A complete Form B (community rights), just filed: waiting for the Gram Sabha.
    final b1 = await open(villager, 'cr');
    await fill(villager, b1, 'form-b', _formB());
    await act(villager, b1, 'submit');

    // 3. A Form A the Gram Sabha sent back with a remark: the villager has 60 days to correct it.
    final a2 = await open(villager, 'ifr');
    await fill(villager, a2, 'form-a', _formA('Lata Bhoye', 'Dattu Bhoye', 0.8, 'Land near the stream'));
    await act(villager, a2, 'submit');
    await act(gramSabha, a2, 'return',
        remarks: 'Please add the survey number of the plot and a second piece of evidence.');

    // 4. A Form A still being written.
    final a3 = await open(villager, 'ifr');
    await fill(villager, a3, 'form-a', {
      'claimant_names': ['Kisan Pawar'],
      'address': 'Ozhar, Jawhar',
    });

    // 5. A second village user's own Form A (to show that each person sees only their claims).
    final a4 = await open(villager2, 'ifr');
    await fill(villager2, a4, 'form-a', _formA('Meena Pawar', 'Raju Pawar', 0.6, 'House plot and kitchen garden'));

    // 6. The Gram Sabha's own Form C (community forest resource), partly filled.
    final c1 = await open(gramSabha, 'cfr');
    await fill(gramSabha, c1, 'form-c', {
      'area_description': 'Forest east of the village, used for grazing and firewood',
      'approx_area_ha': 120.5,
      'pastoral_seasonal_use': false,
      'landmarks': [
        {'side': 'east', 'kind': 'stream', 'name': 'Nagdevta stream'},
        {'side': 'north', 'kind': 'hill', 'name': 'Kalsubai'},
      ],
      'khasra_compartment_numbers': ['C-12', 'C-14'],
      'bordering_villages': [
        {'name': 'Chambharshet', 'shares_resources': true, 'sharing_details': 'Grazing'},
      ],
      'evidence': [
        {'rule_ref': '13(1)(a)', 'description': 'Gazetteer extract'},
      ],
    });

    // keep the SDO token used: the SDO has nothing to do yet (claim 1 waits in its queue)
    assert(sdo.isNotEmpty);
  }

  static Map<String, dynamic> _formA(String name, String spouse, double ha, String where) => {
        'claimant_names': [name, spouse],
        'spouse_name': spouse,
        'father_mother_name': 'Laxman ${name.split(' ').last}',
        'address': 'Ozhar, Jawhar, Palghar',
        'is_scheduled_tribe': true,
        'is_otfd': false,
        'spouse_is_scheduled_tribe': true,
        'family_members': [
          {'name': 'Asha', 'age': 12, 'relation': 'daughter'},
          {'name': 'Ravi', 'age': 8, 'relation': 'son'},
        ],
        'claims': {
          'self_cultivation': {'extent_ha': ha, 'details': where},
          'habitation': {'extent_ha': 0.1, 'details': 'House plot'},
        },
        'evidence': [
          {'rule_ref': '13(1)(a)', 'description': '7/12 extract'},
          {'rule_ref': '13(1)(i)', 'description': 'Statement of village elders'},
        ],
        'other_information': 'Cultivating this land since 1990',
      };

  static Map<String, dynamic> _formB() => {
        'claimant_names': ['Ozhar Gram Sabha'],
        'is_fdst_community': true,
        'is_otfd_community': false,
        'rights': {
          'nistar': {
            'details': 'Firewood and bamboo for the village',
            'items': ['bamboo', 'firewood'],
            'survey_compartment_numbers': ['12', '13'],
            'total_area_ha': 40.5,
            'boundaries': {'east': 'Nagdevta stream', 'north': 'Village road'},
            'annual_quantity': 'As needed',
          },
          'grazing': {'details': 'Cattle graze on the hill'},
        },
        'evidence': [
          {'rule_ref': '13(1)(a)', 'description': 'Nistar patrak'},
          {'rule_ref': '13(2)(b)', 'description': 'Grazing ground record'},
        ],
        'other_information': null,
      };
}
