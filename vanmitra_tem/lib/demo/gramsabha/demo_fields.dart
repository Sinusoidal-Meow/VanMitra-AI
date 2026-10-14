import '../core/demo_core.dart';

/// Request-body checks that give the same 422 answer as the real server's Pydantic models:
/// `{error: VALIDATION_ERROR, message_key: validation.invalid, details: {errors: [...]}}` where
/// each error has `type`, `loc`, `msg` and `input`. Collect every problem, then call [check].
class Fields {
  Fields.body(Object? body)
      : errors = [],
        _loc = const ['body'],
        _map = body is Map ? Map<String, dynamic>.from(body) : const {},
        _input = body {
    if (body is! Map) {
      _add('model_attributes_type', const [],
          'Input should be a valid dictionary or object to extract fields from', body);
    }
  }

  Fields._(this.errors, this._loc, this._map, this._input);

  /// Every problem found so far, shared with nested [Fields].
  final List<Map<String, dynamic>> errors;
  final List<Object> _loc;
  final Map<String, dynamic> _map;
  final Object? _input;

  bool has(String field) => _map.containsKey(field);

  void _add(String type, List<Object> loc, String msg, Object? input) {
    errors.add({
      'type': type,
      'loc': [..._loc, ...loc],
      'msg': msg,
      'input': input,
    });
  }

  /// The value of [field], or null; a missing required field is an error.
  Object? _raw(String field, bool required) {
    if (!_map.containsKey(field)) {
      if (required) _add('missing', [field], 'Field required', _input);
      return null;
    }
    final v = _map[field];
    if (v == null && required) {
      _add('type_error', [field], 'Input should not be null', null);
    }
    return v;
  }

  String? _string(String field, int min, int max, bool required) {
    final v = _raw(field, required);
    if (v == null) return null;
    if (v is! String) {
      _add('string_type', [field], 'Input should be a valid string', v);
      return null;
    }
    final s = v.trim();
    if (s.length < min) {
      _add('string_too_short', [field], 'String should have at least $min character', v);
      return null;
    }
    if (s.length > max) {
      _add('string_too_long', [field], 'String should have at most $max characters', v);
      return null;
    }
    return s;
  }

  /// Trimmed text, 1..[max] characters.
  String? text(String field, {int max = 8000, bool required = true}) =>
      _string(field, 1, max, required);

  /// Trimmed one-line text, 1..300 characters.
  String? line(String field, {bool required = true}) => _string(field, 1, 300, required);

  /// A calendar date `YYYY-MM-DD` (a date-time's date part is accepted).
  String? date(String field, {bool required = true}) {
    final v = _raw(field, required);
    if (v == null) return null;
    final parsed = v is String ? parseIsoDate(v) : null;
    if (parsed == null) {
      _add('date_from_datetime_parsing', [field],
          'Input should be a valid date or datetime, invalid character in year', v);
    }
    return parsed;
  }

  String? uuid(String field, {bool required = true}) {
    final v = _raw(field, required);
    if (v == null) return null;
    final parsed = v is String ? parseUuid(v) : null;
    if (parsed == null) {
      _add(
          'uuid_parsing',
          [field],
          'Input should be a valid UUID, invalid character: expected an optional prefix of `urn:uuid:` followed by [0-9a-fA-F-], found `${v is String && v.isNotEmpty ? v[0] : v}` at 1',
          v);
    }
    return parsed;
  }

  /// A true/false flag; [fallback] when it is not sent.
  bool boolean(String field, {bool fallback = false}) {
    if (!_map.containsKey(field)) return fallback;
    final v = _map[field];
    final parsed = parseBool(v);
    if (parsed == null) {
      _add(
          'bool_parsing', [field], 'Input should be a valid boolean, unable to interpret input', v);
      return fallback;
    }
    return parsed;
  }

  /// A true/false flag that may be sent as null or left out (null then).
  bool? optionalBoolean(String field) {
    if (!_map.containsKey(field) || _map[field] == null) return null;
    final v = _map[field];
    final parsed = parseBool(v);
    if (parsed == null) {
      _add(
          'bool_parsing', [field], 'Input should be a valid boolean, unable to interpret input', v);
    }
    return parsed;
  }

  /// A whole number of at least [min].
  int? integer(String field, {int min = 0, bool required = true}) {
    final v = _raw(field, required);
    if (v == null) return null;
    int? n;
    if (v is int) {
      n = v;
    } else if (v is double && v == v.truncateToDouble()) {
      n = v.toInt();
    } else if (v is String) {
      n = int.tryParse(v.trim());
    }
    if (n == null || v is bool) {
      _add('int_parsing', [field],
          'Input should be a valid integer, unable to parse string as an integer', v);
      return null;
    }
    if (n < min) {
      _add('greater_than_equal', [field], 'Input should be greater than or equal to $min', v);
      return null;
    }
    return n;
  }

  /// One of [values] (a Python enum).
  String? choice(String field, List<String> values, {bool required = true, bool literal = false}) {
    final v = _raw(field, required);
    if (v == null) return null;
    if (v is String && values.contains(v)) return v;
    final names = [for (final x in values) "'$x'"];
    final listed = names.length > 1
        ? '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}'
        : names.first;
    _add(literal ? 'literal_error' : 'enum', [field], 'Input should be $listed', v);
    return null;
  }

  /// A list of UUIDs, at most [max] long.
  List<String>? uuidList(String field, {int max = 5000, bool required = true}) {
    final v = _raw(field, required);
    if (v == null) return null;
    if (v is! List) {
      _add('list_type', [field], 'Input should be a valid list', v);
      return null;
    }
    if (v.length > max) {
      _add('too_long', [field],
          'List should have at most $max items after validation, not ${v.length}', v);
      return null;
    }
    final out = <String>[];
    for (var i = 0; i < v.length; i++) {
      final id = v[i] is String ? parseUuid(v[i] as String) : null;
      if (id == null) {
        _add('uuid_parsing', [field, i], 'Input should be a valid UUID', v[i]);
      } else {
        out.add(id);
      }
    }
    return out;
  }

  /// A list of objects, 1..[max] long, each checked by [item].
  List<T>? objects<T>(
    String field,
    T Function(Fields item) item, {
    int min = 1,
    int max = 100,
    bool required = true,
  }) {
    final v = _raw(field, required);
    if (v == null) return null;
    if (v is! List) {
      _add('list_type', [field], 'Input should be a valid list', v);
      return null;
    }
    if (v.length < min) {
      _add('too_short', [field],
          'List should have at least $min item after validation, not ${v.length}', v);
      return null;
    }
    if (v.length > max) {
      _add('too_long', [field],
          'List should have at most $max items after validation, not ${v.length}', v);
      return null;
    }
    final out = <T>[];
    for (var i = 0; i < v.length; i++) {
      final one = v[i];
      final sub = Fields._(
        errors,
        [..._loc, field, i],
        one is Map ? Map<String, dynamic>.from(one) : const {},
        one,
      );
      if (one is! Map) {
        sub._add('model_attributes_type', const [],
            'Input should be a valid dictionary or object to extract fields from', one);
        continue;
      }
      out.add(item(sub));
    }
    return out;
  }

  /// Throw the 422 answer if anything was wrong.
  void check() {
    if (errors.isNotEmpty) {
      throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid',
          details: {'errors': List<Map<String, dynamic>>.of(errors)});
    }
  }
}

/// `YYYY-MM-DD` (optionally followed by a time), or null when it is not a real date.
String? parseIsoDate(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ].*)?$').firstMatch(s.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final check = DateTime.utc(y, mo, d);
  if (check.year != y || check.month != mo || check.day != d || y < 1) return null;
  return dateOnly(check);
}

final RegExp _uuidRe =
    RegExp(r'^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$');

/// The id as lowercase text with hyphens, or null when it is not a UUID.
String? parseUuid(String s) {
  final t = s.trim().toLowerCase();
  if (!_uuidRe.hasMatch(t)) return null;
  final h = t.replaceAll('-', '');
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

bool? parseBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v == 1 ? true : (v == 0 ? false : null);
  if (v is String) {
    switch (v.trim().toLowerCase()) {
      case 'true' || 't' || 'yes' || 'y' || 'on' || '1':
        return true;
      case 'false' || 'f' || 'no' || 'n' || 'off' || '0':
        return false;
    }
  }
  return null;
}

/// A path or query id that must be a UUID, else the same 422 the real server gives.
String requireUuid(String where, String name, String value) {
  final id = parseUuid(value);
  if (id == null) {
    throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
      'errors': [
        {
          'type': 'uuid_parsing',
          'loc': [where, name],
          'msg': 'Input should be a valid UUID',
          'input': value,
        },
      ],
    });
  }
  return id;
}
