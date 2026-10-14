import '../core/demo_core.dart';
import 'demo_form_rules.dart';

/// Checking what the app sends when it saves a form, as the real server does with its Pydantic
/// models (schemas/form_a.py, form_b.py, form_c.py): required fields, string lengths (after
/// trimming), numbers in range, the vocabularies, duplicate claimant names. A bad body answers
/// 422 `VALIDATION_ERROR` with `details.errors` in Pydantic's shape (`type`, `loc`, `msg`,
/// `input`, `ctx`). Each parser returns the cleaned input: trimmed strings, defaults filled in.

class _Absent {
  const _Absent();
}

const _absent = _Absent();

/// Collects every problem of one body (so the app can show them all).
class _Check {
  final List<Map<String, dynamic>> errors = [];

  void add(List<Object> loc, String type, String msg, Object? input, [Map<String, dynamic>? ctx]) {
    errors.add({
      'type': type,
      'loc': List<Object>.of(loc),
      'msg': msg,
      'input': input,
      if (ctx != null) 'ctx': ctx,
    });
  }

  void missing(List<Object> loc, Object? parent) =>
      add(loc, 'missing', 'Field required', parent);

  Never raise() => throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid',
      details: {'errors': errors});
}

Object? _get(Map m, String key) => m.containsKey(key) ? m[key] : _absent;

String _plural(int n, String one, String many) => n == 1 ? one : many;

/// The body as a map, or a 422 when it is missing or not an object.
Map<String, dynamic> _bodyMap(_Check c, Object? body) {
  if (body == null) {
    c.add(['body'], 'missing', 'Field required', null);
    c.raise();
  }
  if (body is! Map) {
    c.add(['body'], 'model_attributes_type',
        'Input should be a valid dictionary or object to extract fields from', body);
    c.raise();
  }
  return Map<String, dynamic>.from(body);
}

/// A nested object, or null (error noted) when it is not one.
Map<String, dynamic>? _objectOf(_Check c, List<Object> loc, Object? v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  c.add(loc, 'model_attributes_type',
      'Input should be a valid dictionary or object to extract fields from', v);
  return null;
}

/// A text with `strip_whitespace`, `min_length=1` and a longest length.
String? _str(
  _Check c,
  List<Object> loc,
  Object? v, {
  required int max,
  bool nullable = false,
  bool required = false,
  Object? parent,
}) {
  if (identical(v, _absent)) {
    if (required) c.missing(loc, parent);
    return null;
  }
  if (v == null) {
    if (!nullable) c.add(loc, 'string_type', 'Input should be a valid string', v);
    return null;
  }
  if (v is! String) {
    c.add(loc, 'string_type', 'Input should be a valid string', v);
    return null;
  }
  final s = v.trim();
  final n = s.runes.length;
  if (n < 1) {
    c.add(loc, 'string_too_short', 'String should have at least 1 character', v,
        {'min_length': 1});
    return null;
  }
  if (n > max) {
    c.add(loc, 'string_too_long', 'String should have at most $max characters', v,
        {'max_length': max});
    return null;
  }
  return s;
}

bool? _bool(_Check c, List<Object> loc, Object? v, {bool nullable = false, bool? byDefault}) {
  if (identical(v, _absent)) return byDefault;
  if (v == null) {
    if (!nullable) c.add(loc, 'bool_type', 'Input should be a valid boolean', v);
    return null;
  }
  if (v is bool) return v;
  const yes = {'1', 'on', 't', 'true', 'y', 'yes'};
  const no = {'0', 'off', 'f', 'false', 'n', 'no'};
  if (v is num && (v == 1 || v == 0)) return v == 1;
  if (v is String) {
    final t = v.trim().toLowerCase();
    if (yes.contains(t)) return true;
    if (no.contains(t)) return false;
  }
  if (v is String || v is num) {
    c.add(loc, 'bool_parsing', 'Input should be a valid boolean, unable to interpret input', v);
  } else {
    c.add(loc, 'bool_type', 'Input should be a valid boolean', v);
  }
  return null;
}

/// A number in `[ge, le]`, or null when absent or null.
double? _float(_Check c, List<Object> loc, Object? v, {required num ge, required num le}) {
  if (identical(v, _absent) || v == null) return null;
  double? x;
  if (v is num) {
    x = v.toDouble();
  } else if (v is String) {
    x = double.tryParse(v.trim());
    if (x == null) {
      c.add(loc, 'float_parsing',
          'Input should be a valid number, unable to parse string as a number', v);
      return null;
    }
  } else {
    c.add(loc, 'float_type', 'Input should be a valid number', v);
    return null;
  }
  if (x < ge) {
    c.add(loc, 'greater_than_equal', 'Input should be greater than or equal to $ge', v,
        {'ge': ge});
    return null;
  }
  if (x > le) {
    c.add(loc, 'less_than_equal', 'Input should be less than or equal to $le', v, {'le': le});
    return null;
  }
  return x;
}

/// A whole number in `[ge, le]`, or null when absent or null.
int? _int(_Check c, List<Object> loc, Object? v, {required int ge, required int le}) {
  if (identical(v, _absent) || v == null) return null;
  int? x;
  if (v is int) {
    x = v;
  } else if (v is double) {
    if (v != v.truncateToDouble() || v.isInfinite || v.isNaN) {
      c.add(loc, 'int_from_float',
          'Input should be a valid integer, got a number with a fractional part', v);
      return null;
    }
    x = v.toInt();
  } else if (v is String) {
    x = int.tryParse(v.trim());
    if (x == null) {
      c.add(loc, 'int_parsing',
          'Input should be a valid integer, unable to parse string as an integer', v);
      return null;
    }
  } else {
    c.add(loc, 'int_type', 'Input should be a valid integer', v);
    return null;
  }
  if (x < ge) {
    c.add(loc, 'greater_than_equal', 'Input should be greater than or equal to $ge', v,
        {'ge': ge});
    return null;
  }
  if (x > le) {
    c.add(loc, 'less_than_equal', 'Input should be less than or equal to $le', v, {'le': le});
    return null;
  }
  return x;
}

String _expected(List<String> values) {
  final quoted = [for (final v in values) "'$v'"];
  if (quoted.length == 1) return quoted.first;
  return '${quoted.sublist(0, quoted.length - 1).join(', ')} or ${quoted.last}';
}

String? _enum(
  _Check c,
  List<Object> loc,
  Object? v,
  List<String> values, {
  bool required = false,
  Object? parent,
  bool isKey = false,
}) {
  if (identical(v, _absent)) {
    if (required) c.missing(loc, parent);
    return null;
  }
  if (v is String && values.contains(v)) return v;
  final exp = _expected(values);
  c.add(isKey ? [...loc, '[key]'] : loc, 'enum', 'Input should be $exp', v, {'expected': exp});
  return null;
}

/// The items of a list (an empty list when absent). `max_length` is checked like Pydantic does.
List<Object?> _items(_Check c, List<Object> loc, Object? v, {required int max}) {
  if (identical(v, _absent)) return const [];
  if (v is! List) {
    c.add(loc, 'list_type', 'Input should be a valid list', v);
    return const [];
  }
  if (v.length > max) {
    c.add(loc, 'too_long',
        'List should have at most $max ${_plural(max, 'item', 'items')} after validation, not ${v.length}',
        v, {'field_type': 'List', 'max_length': max, 'actual_length': v.length});
    return const [];
  }
  return v;
}

List<String> _strings(_Check c, List<Object> loc, Object? v, {required int maxItems, required int maxLen}) {
  final out = <String>[];
  final raw = _items(c, loc, v, max: maxItems);
  for (var i = 0; i < raw.length; i++) {
    final s = _str(c, [...loc, i], raw[i], max: maxLen);
    if (s != null) out.add(s);
  }
  return out;
}

/// `claimant_names`: names are unique ignoring capitals.
List<String> _claimantNames(_Check c, Map<String, dynamic> m, {required int maxItems, required bool namedError}) {
  const loc = <Object>['body', 'claimant_names'];
  final before = c.errors.length;
  final names = _strings(c, loc, _get(m, 'claimant_names'), maxItems: maxItems, maxLen: 200);
  if (c.errors.length == before) {
    final seen = <String>{};
    for (final n in names) {
      if (!seen.add(n.toLowerCase())) {
        c.add(loc, 'value_error',
            namedError ? 'Value error, duplicate claimant name: $n' : 'Value error, duplicate claimant name',
            _get(m, 'claimant_names'), {'error': <String, dynamic>{}});
        break;
      }
    }
  }
  return names;
}

/// `evidence`: a list of `{rule_ref, description}`.
List<Map<String, dynamic>> _evidence(_Check c, Map<String, dynamic> m) {
  const loc = <Object>['body', 'evidence'];
  final out = <Map<String, dynamic>>[];
  final raw = _items(c, loc, _get(m, 'evidence'), max: 200);
  for (var i = 0; i < raw.length; i++) {
    final at = [...loc, i];
    final e = _objectOf(c, at, raw[i]);
    if (e == null) continue;
    final rule = _enum(c, [...at, 'rule_ref'], _get(e, 'rule_ref'), evidenceRules,
        required: true, parent: e);
    final desc = _str(c, [...at, 'description'], _get(e, 'description'),
        max: 1000, required: true, parent: e);
    if (rule != null && desc != null) out.add({'rule_ref': rule, 'description': desc});
  }
  return out;
}

// ── Form A ───────────────────────────────────────────────────────────────────────

/// The cleaned `FormAInput`: claimant_names, spouse_name, father_mother_name, address,
/// is_scheduled_tribe, is_otfd, spouse_is_scheduled_tribe, family_members `[{name, age,
/// relation}]`, claims `{code: {extent_ha, details}}`, evidence `[{rule_ref, description}]`,
/// other_information.
Map<String, dynamic> parseFormAInput(Object? body) {
  final c = _Check();
  final m = _bodyMap(c, body);
  const root = <Object>['body'];

  final names = _claimantNames(c, m, maxItems: 20, namedError: false);
  final spouse = _str(c, [...root, 'spouse_name'], _get(m, 'spouse_name'), max: 200, nullable: true);
  final parent = _str(c, [...root, 'father_mother_name'], _get(m, 'father_mother_name'),
      max: 200, nullable: true);
  final address = _str(c, [...root, 'address'], _get(m, 'address'), max: 4000, nullable: true);
  final st = _bool(c, [...root, 'is_scheduled_tribe'], _get(m, 'is_scheduled_tribe'), nullable: true);
  final otfd = _bool(c, [...root, 'is_otfd'], _get(m, 'is_otfd'), nullable: true);
  final spouseSt = _bool(c, [...root, 'spouse_is_scheduled_tribe'], _get(m, 'spouse_is_scheduled_tribe'),
      nullable: true);

  final family = <Map<String, dynamic>>[];
  const famLoc = <Object>['body', 'family_members'];
  final famRaw = _items(c, famLoc, _get(m, 'family_members'), max: 50);
  for (var i = 0; i < famRaw.length; i++) {
    final at = [...famLoc, i];
    final f = _objectOf(c, at, famRaw[i]);
    if (f == null) continue;
    final name = _str(c, [...at, 'name'], _get(f, 'name'), max: 200, required: true, parent: f);
    final age = _int(c, [...at, 'age'], _get(f, 'age'), ge: 0, le: 130);
    final relation =
        _str(c, [...at, 'relation'], _get(f, 'relation'), max: 100, nullable: true);
    family.add({'name': name, 'age': age, 'relation': relation});
  }

  final claims = <String, Map<String, dynamic>>{};
  const claimLoc = <Object>['body', 'claims'];
  final claimsRaw = _get(m, 'claims');
  if (!identical(claimsRaw, _absent)) {
    if (claimsRaw is! Map) {
      c.add(claimLoc, 'dict_type', 'Input should be a valid dictionary', claimsRaw);
    } else {
      for (final entry in claimsRaw.entries) {
        final key = '${entry.key}';
        final at = [...claimLoc, key];
        final code = _enum(c, at, key, formAClaims.map((s) => s.code).toList(), isKey: true);
        final item = _objectOf(c, at, entry.value);
        if (item == null) continue;
        final extent = _float(c, [...at, 'extent_ha'], _get(item, 'extent_ha'), ge: 0, le: 10000);
        final details = _str(c, [...at, 'details'], _get(item, 'details'),
            max: 4000, required: true, parent: item);
        if (code != null) claims[code] = {'extent_ha': extent, 'details': details};
      }
    }
  }

  final evidence = _evidence(c, m);
  final other = _str(c, [...root, 'other_information'], _get(m, 'other_information'),
      max: 4000, nullable: true);

  if (c.errors.isNotEmpty) c.raise();
  return {
    'claimant_names': names,
    'spouse_name': spouse,
    'father_mother_name': parent,
    'address': address,
    'is_scheduled_tribe': st,
    'is_otfd': otfd,
    'spouse_is_scheduled_tribe': spouseSt,
    'family_members': family,
    'claims': claims,
    'evidence': evidence,
    'other_information': other,
  };
}

// ── Form B ───────────────────────────────────────────────────────────────────────

/// The cleaned `FormBInput`: claimant_names, is_fdst_community, is_otfd_community, rights
/// `{code: {details, items, survey_compartment_numbers, total_area_ha, common_use_area_ha,
/// boundaries {east, west, north, south} | null, annual_quantity}}`, evidence, other_information.
Map<String, dynamic> parseFormBInput(Object? body) {
  final c = _Check();
  final m = _bodyMap(c, body);
  const root = <Object>['body'];

  final names = _claimantNames(c, m, maxItems: 100, namedError: true);
  final fdst = _bool(c, [...root, 'is_fdst_community'], _get(m, 'is_fdst_community'), nullable: true);
  final otfd = _bool(c, [...root, 'is_otfd_community'], _get(m, 'is_otfd_community'), nullable: true);

  final rights = <String, Map<String, dynamic>>{};
  const rightsLoc = <Object>['body', 'rights'];
  final rightsRaw = _get(m, 'rights');
  if (!identical(rightsRaw, _absent)) {
    if (rightsRaw is! Map) {
      c.add(rightsLoc, 'dict_type', 'Input should be a valid dictionary', rightsRaw);
    } else {
      for (final entry in rightsRaw.entries) {
        final key = '${entry.key}';
        final at = [...rightsLoc, key];
        final code = _enum(c, at, key, formBRights.map((s) => s.code).toList(), isKey: true);
        final r = _objectOf(c, at, entry.value);
        if (r == null) continue;
        final details = _str(c, [...at, 'details'], _get(r, 'details'),
            max: 4000, required: true, parent: r);
        final items = _strings(c, [...at, 'items'], _get(r, 'items'), maxItems: 50, maxLen: 200);
        final survey = _strings(c, [...at, 'survey_compartment_numbers'],
            _get(r, 'survey_compartment_numbers'), maxItems: 200, maxLen: 50);
        final total = _float(c, [...at, 'total_area_ha'], _get(r, 'total_area_ha'), ge: 0, le: 1000000);
        final common = _float(c, [...at, 'common_use_area_ha'], _get(r, 'common_use_area_ha'),
            ge: 0, le: 1000000);
        Map<String, dynamic>? boundaries;
        final bRaw = _get(r, 'boundaries');
        if (!identical(bRaw, _absent) && bRaw != null) {
          final bAt = [...at, 'boundaries'];
          final b = _objectOf(c, bAt, bRaw);
          if (b != null) {
            boundaries = {
              for (final side in const ['east', 'west', 'north', 'south'])
                side: _str(c, [...bAt, side], _get(b, side), max: 200, nullable: true),
            };
          }
        }
        final quantity = _str(c, [...at, 'annual_quantity'], _get(r, 'annual_quantity'),
            max: 4000, nullable: true);
        if (code != null) {
          rights[code] = {
            'details': details,
            'items': items,
            'survey_compartment_numbers': survey,
            'total_area_ha': total,
            'common_use_area_ha': common,
            'boundaries': boundaries,
            'annual_quantity': quantity,
          };
        }
      }
    }
  }

  final evidence = _evidence(c, m);
  final other = _str(c, [...root, 'other_information'], _get(m, 'other_information'),
      max: 4000, nullable: true);

  if (c.errors.isNotEmpty) c.raise();
  return {
    'claimant_names': names,
    'is_fdst_community': fdst,
    'is_otfd_community': otfd,
    'rights': rights,
    'evidence': evidence,
    'other_information': other,
  };
}

// ── Form C ───────────────────────────────────────────────────────────────────────

/// The cleaned `FormCInput`: resolution_statement (null keeps the printed default),
/// area_description, approx_area_ha, pastoral_seasonal_use, seasonal_use_details, landmarks
/// `[{side, kind, name, description}]`, khasra_compartment_numbers, bordering_villages
/// `[{name, shares_resources, sharing_details}]`, evidence.
Map<String, dynamic> parseFormCInput(Object? body) {
  final c = _Check();
  final m = _bodyMap(c, body);
  const root = <Object>['body'];

  final statement = _str(c, [...root, 'resolution_statement'], _get(m, 'resolution_statement'),
      max: 4000, nullable: true);
  final area = _str(c, [...root, 'area_description'], _get(m, 'area_description'),
      max: 4000, nullable: true);
  final approx = _float(c, [...root, 'approx_area_ha'], _get(m, 'approx_area_ha'), ge: 0, le: 1000000);
  final pastoral =
      _bool(c, [...root, 'pastoral_seasonal_use'], _get(m, 'pastoral_seasonal_use'), byDefault: false);
  final seasonal = _str(c, [...root, 'seasonal_use_details'], _get(m, 'seasonal_use_details'),
      max: 4000, nullable: true);

  final landmarks = <Map<String, dynamic>>[];
  const lmLoc = <Object>['body', 'landmarks'];
  final lmRaw = _items(c, lmLoc, _get(m, 'landmarks'), max: 200);
  for (var i = 0; i < lmRaw.length; i++) {
    final at = [...lmLoc, i];
    final lm = _objectOf(c, at, lmRaw[i]);
    if (lm == null) continue;
    final side = _enum(c, [...at, 'side'], _get(lm, 'side'), boundarySides, required: true, parent: lm);
    final kind = _enum(c, [...at, 'kind'], _get(lm, 'kind'), landmarkKinds, required: true, parent: lm);
    final name = _str(c, [...at, 'name'], _get(lm, 'name'), max: 200, required: true, parent: lm);
    final desc =
        _str(c, [...at, 'description'], _get(lm, 'description'), max: 4000, nullable: true);
    landmarks.add({'side': side, 'kind': kind, 'name': name, 'description': desc});
  }

  final khasra = _strings(c, [...root, 'khasra_compartment_numbers'],
      _get(m, 'khasra_compartment_numbers'), maxItems: 200, maxLen: 50);

  final bordering = <Map<String, dynamic>>[];
  const bvLoc = <Object>['body', 'bordering_villages'];
  final bvRaw = _items(c, bvLoc, _get(m, 'bordering_villages'), max: 50);
  for (var i = 0; i < bvRaw.length; i++) {
    final at = [...bvLoc, i];
    final b = _objectOf(c, at, bvRaw[i]);
    if (b == null) continue;
    final name = _str(c, [...at, 'name'], _get(b, 'name'), max: 200, required: true, parent: b);
    final shares =
        _bool(c, [...at, 'shares_resources'], _get(b, 'shares_resources'), byDefault: false);
    final details =
        _str(c, [...at, 'sharing_details'], _get(b, 'sharing_details'), max: 4000, nullable: true);
    bordering.add({'name': name, 'shares_resources': shares, 'sharing_details': details});
  }

  final evidence = _evidence(c, m);

  if (c.errors.isNotEmpty) c.raise();
  return {
    'resolution_statement': statement,
    'area_description': area,
    'approx_area_ha': approx,
    'pastoral_seasonal_use': pastoral ?? false,
    'seasonal_use_details': seasonal,
    'landmarks': landmarks,
    'khasra_compartment_numbers': khasra,
    'bordering_villages': bordering,
    'evidence': evidence,
  };
}

/// A path variable that must be a UUID (`case_id`), as FastAPI checks it: 422 when it is not.
/// Returns the id in the form it is stored (lower case, with hyphens).
String parseUuidPath(String name, String raw) {
  var s = raw.trim().toLowerCase();
  if (s.startsWith('urn:uuid:')) s = s.substring(9);
  s = s.replaceAll('{', '').replaceAll('}', '');
  final plain = s.replaceAll('-', '');
  if (RegExp(r'^[0-9a-f]{32}$').hasMatch(plain)) {
    return '${plain.substring(0, 8)}-${plain.substring(8, 12)}-${plain.substring(12, 16)}-'
        '${plain.substring(16, 20)}-${plain.substring(20)}';
  }
  throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid', details: {
    'errors': [
      {
        'type': 'uuid_parsing',
        'loc': ['path', name],
        'msg': 'Input should be a valid UUID, invalid character: expected an optional prefix of '
            '`urn:uuid:` followed by [0-9a-fA-F-], found `${raw.isEmpty ? '' : raw[0]}` at 0',
        'input': raw,
        'ctx': {'error': 'invalid character'},
      },
    ],
  });
}
