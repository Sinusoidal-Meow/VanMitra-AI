import '../core/demo_core.dart';

/// Shared helpers of the procedure slice: body validation in the spirit of the backend's Pydantic
/// models, and the village guards of `auth/deps.py`.

/// Reads and checks a request body. Every problem is collected; [done] answers 422
/// `VALIDATION_ERROR` with `details.errors` (the shape FastAPI gives) when there is any.
class Input {
  Input(Object? body)
      : _map = body is Map ? Map<String, dynamic>.from(body) : null,
        _missingBody = body is! Map;

  final Map<String, dynamic>? _map;
  final bool _missingBody;
  final List<Map<String, dynamic>> errors = [];

  static final RegExp _uuidRe = RegExp(r'^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?'
      r'[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$');
  static final RegExp _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ]00:00:00(?:\.0+)?Z?)?$');

  bool has(String field) => _map?.containsKey(field) ?? false;
  Object? raw(String field) => _map?[field];

  void _err(String field, String type, String msg, [Object? input]) => errors.add({
        'type': type,
        'loc': ['body', field],
        'msg': msg,
        'input': input,
      });

  /// Stop with 422 when any field was refused.
  void done() {
    if (_missingBody) {
      errors.insert(0, {
        'type': 'missing',
        'loc': ['body'],
        'msg': 'Field required',
        'input': null,
      });
    }
    if (errors.isNotEmpty) {
      throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid',
          details: {'errors': List<Map<String, dynamic>>.from(errors)});
    }
  }

  /// A field that is absent or null: true when it was handled (reported or left as null).
  bool _absent(String field, bool required, bool nullable) {
    final v = _map?[field];
    if (!has(field)) {
      if (required) _err(field, 'missing', 'Field required');
      return true;
    }
    if (v == null) {
      if (!nullable) _err(field, 'string_type', 'Input should not be null', v);
      return true;
    }
    return false;
  }

  /// Text with its edges trimmed, [min]..[max] characters long.
  String? text(
    String field, {
    bool required = true,
    bool nullable = false,
    int min = 1,
    int max = 4000,
    bool strip = true,
  }) {
    if (_absent(field, required, nullable)) return null;
    final v = _map![field];
    if (v is! String) {
      _err(field, 'string_type', 'Input should be a valid string', v);
      return null;
    }
    final s = strip ? v.trim() : v;
    if (s.length < min) {
      _err(field, 'string_too_short', 'String should have at least $min characters', v);
      return null;
    }
    if (s.length > max) {
      _err(field, 'string_too_long', 'String should have at most $max characters', v);
      return null;
    }
    return s;
  }

  /// A calendar date `YYYY-MM-DD`.
  String? date(String field, {bool required = true, bool nullable = false}) {
    if (_absent(field, required, nullable)) return null;
    return _dateOf(field, _map![field]);
  }

  String? _dateOf(String field, Object? v) {
    final m = v is String ? _dateRe.firstMatch(v.trim()) : null;
    if (m != null) {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final parsed = DateTime.utc(y, mo, d);
      if (parsed.year == y && parsed.month == mo && parsed.day == d) return dateOnly(parsed);
    }
    _err(field, 'date_from_datetime_parsing', 'Input should be a valid date', v);
    return null;
  }

  /// A UUID, written the same way every time (lower case, with hyphens).
  String? uuid(String field, {bool required = true, bool nullable = false}) {
    if (_absent(field, required, nullable)) return null;
    return _uuidOf(field, _map![field]);
  }

  String? _uuidOf(String field, Object? v) {
    if (v is String && _uuidRe.hasMatch(v)) return normaliseUuid(v);
    _err(field, 'uuid_parsing', 'Input should be a valid UUID', v);
    return null;
  }

  static String normaliseUuid(String v) {
    final h = v.replaceAll('-', '').toLowerCase();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// One of [values] (an enum written as its string value).
  String? choice(
    String field,
    Set<String> values, {
    String? defaultValue,
    bool required = false,
  }) {
    if (!has(field)) {
      if (required && defaultValue == null) _err(field, 'missing', 'Field required');
      return defaultValue;
    }
    final v = _map![field];
    if (v is String && values.contains(v)) return v;
    _err(field, 'enum', 'Input should be ${values.map((e) => "'$e'").join(', ')}', v);
    return defaultValue;
  }

  /// A whole number between [min] and [max], or [defaultValue] when absent.
  int? integer(String field, {required int min, required int max, int? defaultValue}) {
    if (!has(field)) return defaultValue;
    final v = _map![field];
    int? n;
    if (v is int) {
      n = v;
    } else if (v is double && v == v.truncateToDouble()) {
      n = v.toInt();
    } else if (v is String) {
      n = int.tryParse(v.trim());
    }
    if (n == null) {
      _err(field, 'int_parsing', 'Input should be a valid integer', v);
      return defaultValue;
    }
    if (n < min) {
      _err(field, 'greater_than_equal', 'Input should be greater than or equal to $min', v);
      return defaultValue;
    }
    if (n > max) {
      _err(field, 'less_than_equal', 'Input should be less than or equal to $max', v);
      return defaultValue;
    }
    return n;
  }

  /// A list of UUIDs of at most [max] items (required unless [defaultEmpty]).
  List<String>? uuidList(String field, {required int max}) {
    if (!has(field)) {
      _err(field, 'missing', 'Field required');
      return null;
    }
    final v = _map![field];
    if (v is! List) {
      _err(field, 'list_type', 'Input should be a valid list', v);
      return null;
    }
    if (v.length > max) {
      _err(field, 'too_long', 'List should have at most $max items after validation', v);
      return null;
    }
    final out = <String>[];
    for (final item in v) {
      final id = _uuidOf(field, item);
      if (id != null) out.add(id);
    }
    return out;
  }

  /// A list of short text lines; an absent list is empty.
  List<String> textList(String field, {required int max, int itemMax = 300}) {
    if (!has(field)) return <String>[];
    final v = _map![field];
    if (v is! List) {
      _err(field, 'list_type', 'Input should be a valid list', v);
      return <String>[];
    }
    if (v.length > max) {
      _err(field, 'too_long', 'List should have at most $max items after validation', v);
      return <String>[];
    }
    final out = <String>[];
    for (final item in v) {
      if (item is! String) {
        _err(field, 'string_type', 'Input should be a valid string', item);
        continue;
      }
      final s = item.trim();
      if (s.isEmpty || s.length > itemMax) {
        _err(field, s.isEmpty ? 'string_too_short' : 'string_too_long',
            'String should have between 1 and $itemMax characters', item);
        continue;
      }
      out.add(s);
    }
    return out;
  }
}

/// A valid UUID typed in a query string, or 422 like FastAPI.
String? queryUuid(DemoRequest r, String name) {
  final v = r.q(name);
  if (v == null) return null;
  final input = Input({name: v});
  final id = input.uuid(name);
  if (input.errors.isNotEmpty) {
    throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
      'errors': [
        for (final e in input.errors) {...e, 'loc': ['query', name]},
      ],
    });
  }
  return id;
}

// ── guards (auth/deps.py) ──────────────────────────────────────────────────────

class ProcedureGuards {
  ProcedureGuards._();

  /// `require_village_role`: the village of the path if the caller holds one of [roles] there
  /// (any role covering the village when [roles] is null).
  static Map<String, dynamic> village(DemoRequest req, [Iterable<String>? roles]) {
    final p = req.who;
    final village = req.db.byId('village', req.params['village_id']);
    if (village == null) throw DemoError(404, 'VILLAGE_NOT_FOUND', 'village.not_found');
    if (!p.has(village, roles)) {
      throw DemoError(403, 'FORBIDDEN', 'auth.forbidden_in_village', details: {
        'village_id': village['id'],
        'required_roles': roles?.toList() ?? <String>[],
      });
    }
    return village;
  }

  /// `require_admin`: back-office only.
  static Principal admin(DemoRequest req) {
    final p = req.who;
    if (!p.isAdmin) throw DemoError(403, 'FORBIDDEN', 'auth.admin_only');
    return p;
  }

  /// The village's Gram Sabha, or 409.
  static Map<String, dynamic> gramSabha(DemoDb db, String villageId) {
    final gs = db.findOne('gram_sabha', (g) => g['village_id'] == villageId);
    if (gs == null) throw DemoError(409, 'GRAM_SABHA_MISSING', 'village.gram_sabha_missing');
    return gs;
  }

  /// Rows sorted by [compare], equal rows keeping their order (Dart's sort is not stable).
  static List<T> stableSorted<T>(Iterable<T> rows, int Function(T a, T b) compare) {
    final indexed = [for (var i = 0; i < rows.length; i++) (i, rows.elementAt(i))];
    indexed.sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }
}
