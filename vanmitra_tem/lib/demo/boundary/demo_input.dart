import '../core/demo_core.dart';

/// Checks a request body the way the backend's Pydantic models do, collecting every problem and
/// answering 422 `VALIDATION_ERROR` with `details.errors` (`{type, loc, msg, input}`) like the
/// real server. Only the checks that matter to the app are reproduced.
class Check {
  Check(Object? body) : root = body is Map ? Map<String, dynamic>.from(body) : null {
    if (root == null) _add(['body'], 'model_attributes_type', 'Input should be a valid dictionary', body);
  }

  final Map<String, dynamic>? root;
  final List<Map<String, dynamic>> errors = [];

  static final RegExp _uuid =
      RegExp(r'^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$');
  static final RegExp _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  void _add(List<Object> loc, String type, String msg, Object? input) =>
      errors.add({'type': type, 'loc': loc, 'msg': msg, 'input': input});

  void fail(List<Object> loc, String type, String msg, [Object? input]) =>
      _add(['body', ...loc], type, msg, input);

  /// Throw the 422 if anything was wrong.
  void done() {
    if (errors.isNotEmpty) {
      throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {'errors': errors});
    }
  }

  dynamic raw(String key) => root?[key];

  bool _missing(Map<String, dynamic> m, String key, List<Object> loc, bool required) {
    final v = m[key];
    if (v == null) {
      if (required) fail([...loc, key], 'missing', 'Field required', null);
      return true;
    }
    return false;
  }

  /// A stripped string of [min]..[max] characters; null when absent and not [required].
  String? text(
    Map<String, dynamic> m,
    String key, {
    List<Object> loc = const [],
    bool required = false,
    int min = 0,
    int max = 1 << 30,
  }) {
    if (_missing(m, key, loc, required)) return null;
    final v = m[key];
    if (v is! String) {
      fail([...loc, key], 'string_type', 'Input should be a valid string', v);
      return null;
    }
    final s = v.trim();
    if (s.length < min) {
      fail([...loc, key], 'string_too_short', 'String should have at least $min character${min == 1 ? '' : 's'}', v);
      return null;
    }
    if (s.length > max) {
      fail([...loc, key], 'string_too_long', 'String should have at most $max characters', v);
      return null;
    }
    return s;
  }

  String? choice(
    Map<String, dynamic> m,
    String key,
    Set<String> allowed, {
    List<Object> loc = const [],
    bool required = false,
    String? fallback,
  }) {
    if (m[key] == null) {
      if (fallback != null) return fallback;
      if (required) fail([...loc, key], 'missing', 'Field required', null);
      return null;
    }
    final v = m[key];
    if (v is! String || !allowed.contains(v)) {
      fail([...loc, key], 'enum', "Input should be ${allowed.map((a) => "'$a'").join(', ')}", v);
      return null;
    }
    return v;
  }

  String? uuid(Map<String, dynamic> m, String key, {List<Object> loc = const [], bool required = false}) {
    if (_missing(m, key, loc, required)) return null;
    final v = m[key];
    if (v is! String || !_uuid.hasMatch(v)) {
      fail([...loc, key], 'uuid_parsing', 'Input should be a valid UUID', v);
      return null;
    }
    return v.toLowerCase();
  }

  /// A calendar date `YYYY-MM-DD`.
  String? date(Map<String, dynamic> m, String key, {List<Object> loc = const [], bool required = true}) {
    if (_missing(m, key, loc, required)) return null;
    final v = m[key];
    final g = v is String ? _date.firstMatch(v) : null;
    var ok = g != null;
    if (g != null) {
      final y = int.parse(g.group(1)!), mo = int.parse(g.group(2)!), d = int.parse(g.group(3)!);
      final back = DateTime.utc(y, mo, d);
      ok = mo >= 1 && mo <= 12 && d >= 1 && back.month == mo && back.day == d && y >= 1;
    }
    if (!ok) {
      fail([...loc, key], 'date_from_datetime_parsing', 'Input should be a valid date or datetime', v);
      return null;
    }
    return v as String;
  }

  int? integer(Map<String, dynamic> m, String key,
      {List<Object> loc = const [], bool required = false, int? ge}) {
    if (_missing(m, key, loc, required)) return null;
    final v = m[key];
    final n = v is int ? v : (v is double && v == v.truncateToDouble() ? v.toInt() : null);
    if (n == null) {
      fail([...loc, key], 'int_type', 'Input should be a valid integer', v);
      return null;
    }
    if (ge != null && n < ge) {
      fail([...loc, key], 'greater_than_equal', 'Input should be greater than or equal to $ge', v);
      return null;
    }
    return n;
  }

  double? number(Map<String, dynamic> m, String key,
      {List<Object> loc = const [], bool required = false, double? ge, double? le}) {
    if (_missing(m, key, loc, required)) return null;
    final v = m[key];
    if (v is! num || v is bool) {
      fail([...loc, key], 'float_type', 'Input should be a valid number', v);
      return null;
    }
    final d = v.toDouble();
    if (ge != null && d < ge) {
      fail([...loc, key], 'greater_than_equal', 'Input should be greater than or equal to ${_n(ge)}', v);
      return null;
    }
    if (le != null && d > le) {
      fail([...loc, key], 'less_than_equal', 'Input should be less than or equal to ${_n(le)}', v);
      return null;
    }
    return d;
  }

  static String _n(double d) => d == d.truncateToDouble() ? '${d.toInt()}' : '$d';

  /// A list of length [min]..[max] (null when absent and not [required]).
  List<dynamic>? list(
    Map<String, dynamic> m,
    String key, {
    List<Object> loc = const [],
    bool required = false,
    int min = 0,
    int max = 1 << 30,
  }) {
    if (_missing(m, key, loc, required)) return null;
    final v = m[key];
    if (v is! List) {
      fail([...loc, key], 'list_type', 'Input should be a valid list', v);
      return null;
    }
    if (v.length < min) {
      fail([...loc, key], 'too_short', 'List should have at least $min item${min == 1 ? '' : 's'} after validation, not ${v.length}', v);
      return null;
    }
    if (v.length > max) {
      fail([...loc, key], 'too_long', 'List should have at most $max items after validation, not ${v.length}', v);
      return null;
    }
    return v;
  }

  Map<String, dynamic>? object(Map<String, dynamic> m, String key,
      {List<Object> loc = const [], bool required = false}) {
    if (_missing(m, key, loc, required)) return null;
    final v = m[key];
    if (v is! Map) {
      fail([...loc, key], 'model_type', 'Input should be a valid dictionary or object', v);
      return null;
    }
    return Map<String, dynamic>.from(v);
  }

  /// A GeoJSON `Polygon` ([lon, lat] coordinates): rings of 3..5000 positions of 2..3 numbers,
  /// 1..50 rings. Returns the rings as numbers, or null (with the problems recorded).
  List<List<List<num>>>? polygon(Map<String, dynamic> m, String key,
      {List<Object> loc = const [], bool required = true}) {
    final o = object(m, key, loc: loc, required: required);
    if (o == null) return null;
    final at = [...loc, key];
    if (o['type'] != 'Polygon') {
      fail([...at, 'type'], 'literal_error', "Input should be 'Polygon'", o['type']);
    }
    final rings = list(o, 'coordinates', loc: at, required: true, min: 1, max: 50);
    if (rings == null) return null;
    final out = <List<List<num>>>[];
    var ok = o['type'] == 'Polygon';
    for (var i = 0; i < rings.length; i++) {
      final pts = _positions(rings[i], [...at, 'coordinates', i], 3, 5000);
      if (pts == null) {
        ok = false;
      } else {
        out.add(pts);
      }
    }
    return ok ? out : null;
  }

  /// A GeoJSON `LineString`: 2..20000 positions.
  List<List<num>>? lineString(Map<String, dynamic> m, String key,
      {List<Object> loc = const [], bool required = false}) {
    final o = object(m, key, loc: loc, required: required);
    if (o == null) return null;
    final at = [...loc, key];
    var ok = true;
    if (o['type'] != 'LineString') {
      fail([...at, 'type'], 'literal_error', "Input should be 'LineString'", o['type']);
      ok = false;
    }
    final pts = _positions(o['coordinates'], [...at, 'coordinates'], 2, 20000);
    return ok ? pts : null;
  }

  List<List<num>>? _positions(Object? v, List<Object> at, int min, int max) {
    if (v is! List) {
      fail(at, 'list_type', 'Input should be a valid list', v);
      return null;
    }
    if (v.length < min || v.length > max) {
      fail(at, v.length < min ? 'too_short' : 'too_long',
          'List should have ${v.length < min ? 'at least $min' : 'at most $max'} items after validation, not ${v.length}', v);
      return null;
    }
    final out = <List<num>>[];
    var ok = true;
    for (var i = 0; i < v.length; i++) {
      final c = v[i];
      if (c is! List || c.length < 2 || c.length > 3 || c.any((e) => e is! num)) {
        fail([...at, i], c is List && c.any((e) => e is! num) ? 'float_type' : 'too_short',
            c is List && c.any((e) => e is! num)
                ? 'Input should be a valid number'
                : 'List should have 2 to 3 items', c);
        ok = false;
      } else {
        out.add(c.cast<num>());
      }
    }
    return ok ? out : null;
  }
}
