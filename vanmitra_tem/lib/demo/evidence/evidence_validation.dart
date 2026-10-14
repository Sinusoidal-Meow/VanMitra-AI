import '../core/demo_core.dart';

/// Pydantic-style request checking for the evidence, media and document routes: collects every
/// problem and, if there is any, answers 422 `VALIDATION_ERROR` the way the real server does
/// (`details.errors` is a list of `{type, loc, msg, input}`).
class Checker {
  Checker(this.where);

  /// `body`, `query`, `path` or `form`.
  final String where;
  final List<Map<String, dynamic>> errors = [];

  void add(String field, String type, String msg, [Object? input]) => errors.add({
        'type': type,
        'loc': [where, field],
        'msg': msg,
        'input': input,
      });

  /// Throw 422 if anything was wrong.
  void done() {
    if (errors.isEmpty) return;
    throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {'errors': errors});
  }

  /// A text field. Surrounding spaces are removed (as the schemas do); [min]/[max] apply after
  /// that. Returns null when absent (and not [required]) or invalid.
  String? text(
    Map<String, dynamic> m,
    String key, {
    int min = 0,
    int? max,
    bool required = false,
  }) {
    final v = m[key];
    if (v == null) {
      if (required) add(key, 'missing', 'Field required', null);
      return null;
    }
    if (v is! String) {
      add(key, 'string_type', 'Input should be a valid string', v);
      return null;
    }
    final s = v.trim();
    if (s.length < min) {
      add(key, 'string_too_short',
          'String should have at least $min character${min == 1 ? '' : 's'}', v);
      return null;
    }
    if (max != null && s.length > max) {
      add(key, 'string_too_long', 'String should have at most $max characters', v);
      return null;
    }
    return s;
  }

  /// One of [allowed] (an enum's string values).
  String? choice(Map<String, dynamic> m, String key, Iterable<String> allowed,
      {bool required = false}) {
    final v = m[key];
    if (v == null) {
      if (required) add(key, 'missing', 'Field required', null);
      return null;
    }
    if (v is! String || !allowed.contains(v)) {
      add(key, 'enum', "Input should be ${allowed.map((a) => "'$a'").join(', ')}", v);
      return null;
    }
    return v;
  }

  /// A UUID, written in lower case with hyphens. Null when absent or invalid.
  String? uuid(Map<String, dynamic> m, String key, {bool required = false}) {
    final v = m[key];
    if (v == null) {
      if (required) add(key, 'missing', 'Field required', null);
      return null;
    }
    final u = v is String ? normalUuid(v) : null;
    if (u == null) {
      add(key, 'uuid_parsing', 'Input should be a valid UUID', v);
      return null;
    }
    return u;
  }

  /// A calendar date `YYYY-MM-DD`.
  String? date(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is String && isDate(v.trim())) return v.trim();
    add(key, 'date_from_datetime_parsing', 'Input should be a valid date', v);
    return null;
  }

  /// A number (a numeric text is accepted, as in pydantic's default mode).
  double? number(Map<String, dynamic> m, String key, {double? ge, double? le}) {
    final v = m[key];
    if (v == null) return null;
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v.trim());
    }
    if (d == null || d.isNaN) {
      add(key, 'float_parsing', 'Input should be a valid number', v);
      return null;
    }
    if (ge != null && d < ge) {
      add(key, 'greater_than_equal', 'Input should be greater than or equal to ${_n(ge)}', v);
      return null;
    }
    if (le != null && d > le) {
      add(key, 'less_than_equal', 'Input should be less than or equal to ${_n(le)}', v);
      return null;
    }
    return d;
  }

  /// A moment in time, as ISO text; stored as UTC.
  String? moment(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    final t = v is String ? DateTime.tryParse(v.trim()) : null;
    if (t == null) {
      add(key, 'datetime_from_date_parsing', 'Input should be a valid datetime', v);
      return null;
    }
    return t.toUtc().toIso8601String();
  }

  static String _n(double d) => d == d.roundToDouble() ? d.toInt().toString() : '$d';
}

final RegExp _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$',
);

/// The canonical (lower case, hyphenated) form of a UUID text, or null if it is not one.
String? normalUuid(String s) {
  final t = s.trim();
  if (!_uuidRe.hasMatch(t)) return null;
  final h = t.replaceAll('-', '').toLowerCase();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Is [s] a real calendar date `YYYY-MM-DD`?
bool isDate(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return false;
  final y = int.parse(s.substring(0, 4));
  final mo = int.parse(s.substring(5, 7));
  final d = int.parse(s.substring(8, 10));
  if (y < 1 || mo < 1 || mo > 12 || d < 1) return false;
  return d <= DateTime.utc(y, mo + 1, 0).day;
}

/// A path variable that must be a UUID (422 like the real server when it is not).
String pathUuid(DemoRequest req, String name) {
  final u = normalUuid(req.params[name] ?? '');
  if (u == null) {
    throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
      'errors': [
        {
          'type': 'uuid_parsing',
          'loc': ['path', name],
          'msg': 'Input should be a valid UUID',
          'input': req.params[name],
        },
      ],
    });
  }
  return u;
}

/// A query variable that must be a UUID, or absent.
String? queryUuid(DemoRequest req, String name) {
  final v = req.q(name);
  if (v == null) return null;
  final u = normalUuid(v);
  if (u == null) {
    throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
      'errors': [
        {
          'type': 'uuid_parsing',
          'loc': ['query', name],
          'msg': 'Input should be a valid UUID',
          'input': v,
        },
      ],
    });
  }
  return u;
}
