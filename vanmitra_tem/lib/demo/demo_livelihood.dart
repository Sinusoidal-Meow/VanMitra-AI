import 'dart:convert';

import 'core/demo_accounts.dart';
import 'core/demo_core.dart';

/// Module 4 (livelihood) for the offline demo: answers the app's /livelihood calls from the
/// bundled mock data (assets/demo/livelihood_demo.json, made by the real rules for a sample
/// farmer: scripts/export_demo_fixtures.py in the Module 4 repo).
///
/// What is real and what is not, honestly:
///  - the report, every idea's detail, the schemes and the answers to the suggested questions are
///    the real output for ONE sample farmer;
///  - her details can be changed and saved, but the report does NOT change with them (the rules
///    run on the server, not in the phone). The app says so wherever it matters;
///  - a typed question is answered by the nearest suggested question, or with the grey "I can only
///    answer questions about your report", or refused when it asks for harm.
class DemoLivelihood {
  DemoLivelihood(this._fixture, this._state, this._userName);

  final Map<String, dynamic> _fixture;
  final Map<String, dynamic> _state;
  final String _userName;

  Map<String, dynamic> get _scenario {
    final sc = (_fixture['scenarios'] as Map<String, dynamic>)[_hasProfile ? 'farmer' : 'general']
        as Map<String, dynamic>;
    return sc;
  }

  bool get _hasProfile => _state['lv_profile'] != null;

  /// The report with this person's name in its header (the fixture was made for a sample name).
  Map<String, dynamic> _reportForUser() {
    final report = Map<String, dynamic>.from(_scenario['report'] as Map);
    final header = Map<String, dynamic>.from(report['header'] as Map)..['name'] = _userName;
    return {...report, 'header': header};
  }

  /// A person's Module 4 state. The five demo logins start with the sample farmer's details
  /// already saved; anyone who registers starts with none.
  static Map<String, dynamic> stateFor(DemoDb db, Map<String, dynamic> fixture, String userId) {
    final all = db.section('lv');
    return (all[userId] ??= () {
      final seeded = [for (var n = 1; n <= 5; n++) DemoAccounts.userIdFor(n)].contains(userId);
      return <String, dynamic>{
        'lv_profile': seeded ? fixture['profile'] : null,
        'lv_has_report': false,
        'lv_turns': <dynamic>[],
      };
    }()) as Map<String, dynamic>;
  }

  /// Module 4 is for village users and the Gram Sabha, each for their own land.
  static void register(DemoRouter r, Future<Map<String, dynamic>> Function() loadFixture) {
    for (final method in const ['GET', 'POST', 'PUT', 'DELETE']) {
      for (final pattern in const [
        '/livelihood/profile',
        '/livelihood/report',
        '/livelihood/report/latest',
        '/livelihood/schemes',
        '/livelihood/ask',
        '/livelihood/ask/history',
        '/livelihood/ideas/{code}',
      ]) {
        r.add(method, pattern, (req) async {
          final p = req.who;
          if (p.roles.intersection({Roles.villager, Roles.gramSabha}).isEmpty) {
            throw DemoError(403, 'FORBIDDEN', 'livelihood.role_not_allowed');
          }
          final fixture = await loadFixture();
          final lv = DemoLivelihood(fixture, stateFor(req.db, fixture, p.userId), p.name);
          return lv.handle(method, req.path, req.query, req.body);
        });
      }
    }
  }

  bool handles(String path) => path.startsWith('/livelihood/');

  dynamic handle(String method, String path, Map<String, List<String>> query, Object? body) {
    final p = path.substring('/livelihood'.length);
    switch ((method, p)) {
      case ('GET', '/profile'):
        return _state['lv_profile'] ?? _notFound('livelihood.no_profile');
      case ('PUT', '/profile'):
        final saved = Map<String, dynamic>.from(_state['lv_profile'] as Map? ?? _fixture['profile'] as Map);
        saved['profile'] = body;
        saved['updated_at'] = DateTime.now().toUtc().toIso8601String();
        _state['lv_profile'] = saved;
        return saved;
      case ('DELETE', '/profile'):
        // like the server: his details, reports and questions all go
        _state['lv_profile'] = null;
        _state['lv_has_report'] = false;
        _state['lv_turns'] = <dynamic>[];
        return null;
      case ('POST', '/report'):
        _state['lv_has_report'] = true;
        return _reportForUser();
      case ('GET', '/report/latest'):
        return _state['lv_has_report'] == true
            ? _reportForUser()
            : _notFound('livelihood.no_report');
      case ('GET', '/schemes'):
        return _schemes(query);
      case ('POST', '/ask'):
        return _askReply(body as Map<String, dynamic>? ?? const {});
      case ('GET', '/ask/history'):
        return {
          'turns': _state['lv_turns'] ?? const [],
          'chips': _askData['chips'],
          'has_report': true,
          'ai_available': false,
        };
      case ('DELETE', '/ask/history'):
        _state['lv_turns'] = <dynamic>[];
        return null;
    }
    if (method == 'GET' && p.startsWith('/ideas/')) {
      final code = Uri.decodeComponent(p.substring('/ideas/'.length));
      final ideas = _scenario['ideas'] as Map<String, dynamic>;
      return ideas[code] ?? _notFound('livelihood.idea_not_found');
    }
    return _notFound('demo.not_available');
  }

  Map<String, dynamic> get _askData => _scenario['ask'] as Map<String, dynamic>;

  // ── schemes ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _schemes(Map<String, List<String>> q) {
    final all = Map<String, dynamic>.from(_scenario['schemes'] as Map);
    final kind = q['kind']?.firstOrNull;
    final help = q['help']?.firstOrNull;
    final audience = q['audience']?.firstOrNull;
    final rows = (all['schemes'] as List)
        .cast<Map<String, dynamic>>()
        .where((s) => kind == null || s['kind'] == kind)
        .where((s) => help == null || (s['help_types'] as List).contains(help))
        .where((s) => audience == null || (s['audiences'] as List).contains(audience))
        .toList();
    return {...all, 'schemes': rows};
  }

  // ── Ask ────────────────────────────────────────────────────────────────────

  /// Words that point at a suggested question, in English, Marathi and Hindi.
  static const Map<String, List<String>> _topics = {
    'water': ['water', 'well', 'pump', 'irrigat', 'पाणी', 'विहीर', 'पंप', 'पानी', 'कुआं', 'सिंचाई'],
    'cost': ['cost', 'money', 'invest', 'expens', 'खर्च', 'पैसे', 'गुंतवणूक', 'लागत'],
    'forest': ['forest', 'tree', 'wood', 'जंगल', 'वन', 'झाड'],
    'weather': ['weather', 'rain', 'season', 'month', 'हवामान', 'पाऊस', 'मौसम', 'बारिश'],
    'schemes': ['scheme', 'subsid', 'loan', 'योजना', 'अनुदान', 'कर्ज'],
    'removed': ['why not', 'not suggest', 'removed', 'का नाही', 'क्यों नहीं'],
    'own': ['i have', 'own', 'my land', 'माझ्याकडे', 'माझी', 'मेरे पास', 'मेरी'],
    'top_ideas': ['best', 'idea', 'suggest', 'top', 'start', 'कल्पना', 'सुचव', 'सुझाव', 'विचार'],
  };

  /// Words that ask for harm to wildlife or forest. Kept short on purpose: a phrase this list
  /// does not know gets the grey "not in your report" (still no answer), never an answer.
  static const List<String> _harm = [
    'poison', 'kill', 'hunt', 'trap', 'shoot', 'snare', 'electrocut', 'burn the forest',
    'cut the forest', 'cut trees', 'विष', 'मार', 'शिकार', 'जाळ', 'तोड', 'जहर', 'काट',
  ];

  Map<String, dynamic> _answer(String? chip, String? question, String lang) {
    final ask = _askData;
    final chips = (ask['chips'] as List).cast<Map<String, dynamic>>();
    final answers = ask['chip_answers'] as Map<String, dynamic>;

    Map<String, dynamic> template;
    String? storedQuestion = question;
    if (chip != null) {
      template = (answers[chip] ?? ask['off_topic']) as Map<String, dynamic>;
    } else {
      final text = (question ?? '').toLowerCase();
      if (_harm.any(text.contains)) {
        template = ask['refused'] as Map<String, dynamic>;
        storedQuestion = null; // a refused question is not kept
      } else {
        String? found;
        for (final e in _topics.entries) {
          if (e.value.any(text.contains)) {
            found = e.key;
            break;
          }
        }
        // the idea chip ("idea:<code>") is the one named by the first idea of the report
        final ideaChip = chips.map((c) => c['id'] as String).firstWhere(
              (id) => id.startsWith('idea:'),
              orElse: () => '',
            );
        final id = found ?? (text.contains('idea') && ideaChip.isNotEmpty ? ideaChip : null);
        template = (id != null ? answers[id] : null) as Map<String, dynamic>? ??
            ask['off_topic'] as Map<String, dynamic>;
      }
    }

    final report = _scenario['report'] as Map<String, dynamic>;
    final turn = Map<String, dynamic>.from(template)
      ..['id'] = 'demo-${DateTime.now().microsecondsSinceEpoch}'
      ..['at'] = DateTime.now().toUtc().toIso8601String()
      ..['question'] = storedQuestion
      ..['chip'] = chip
      ..['lang'] = lang
      ..['report_id'] = report['id'];
    return {'turn': turn, 'chips': chips};
  }

  Map<String, dynamic> _askReply(Map<String, dynamic> body) {
    final reply = _answer(
      body['chip'] as String?,
      body['question'] as String?,
      body['lang'] as String? ?? 'en',
    );
    final turns = List<dynamic>.from(_state['lv_turns'] as List? ?? const []);
    turns.add(reply['turn']);
    _state['lv_turns'] = turns.length > 50 ? turns.sublist(turns.length - 50) : turns;
    return reply;
  }

  Never _notFound(String key) => throw DemoError(404, 'NOT_FOUND', key);

  /// For tests and for the Sample label: the raw fixture.
  static Map<String, dynamic> decode(String json) => jsonDecode(json) as Map<String, dynamic>;
}
