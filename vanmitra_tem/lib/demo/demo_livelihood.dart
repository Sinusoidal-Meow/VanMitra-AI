import 'dart:convert';

import '../core/api/api_client.dart';

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
  DemoLivelihood(this._fixture, this._state);

  final Map<String, dynamic> _fixture;
  final Map<String, dynamic> _state;

  Map<String, dynamic> get _scenario =>
      (_fixture['scenarios'] as Map<String, dynamic>)[_hasProfile ? 'farmer' : 'general']
          as Map<String, dynamic>;

  bool get _hasProfile => _state['lv_profile'] != null;

  /// The demo starts with the sample farmer's details already saved.
  static void seed(Map<String, dynamic> fixture, Map<String, dynamic> state) {
    if (state.containsKey('lv_profile')) return;
    state['lv_profile'] = fixture['profile'];
    state['lv_has_report'] = false;
    state['lv_turns'] = <dynamic>[];
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
        return _scenario['report'];
      case ('GET', '/report/latest'):
        return _state['lv_has_report'] == true
            ? _scenario['report']
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

  Never _notFound(String key) => throw ApiException(
        statusCode: 404,
        error: 'NOT_FOUND',
        messageKey: key,
      );

  /// For tests and for the Sample label: the raw fixture.
  static Map<String, dynamic> decode(String json) => jsonDecode(json) as Map<String, dynamic>;
}
