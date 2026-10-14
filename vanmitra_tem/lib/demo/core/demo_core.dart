import 'dart:async';

import 'package:uuid/uuid.dart';

/// Shared parts of the OFFLINE DEMO "server" (lib/demo): errors, requests, the router, the
/// in-memory database and the person making the call. Every slice of the demo (accounts, cases,
/// forms, evidence, Gram Sabha ...) is a set of routes registered on one [DemoRouter].

/// A call the demo server refuses, in the same shape the real server uses:
/// `{error, message_key, rule?, details}`.
class DemoError implements Exception {
  DemoError(
    this.status,
    this.error,
    this.messageKey, {
    this.rule,
    this.details = const {},
  });

  final int status;
  final String error;
  final String messageKey;
  final String? rule;
  final Map<String, dynamic> details;

  @override
  String toString() => 'DemoError($status $error)';
}

// ── time ──────────────────────────────────────────────────────────────────────

/// Indian Standard Time: UTC+5:30, no daylight saving. Days counted for villagers (such as the
/// 60 days to resubmit) follow the Indian calendar.
const Duration istOffset = Duration(hours: 5, minutes: 30);

String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A calendar date written `YYYY-MM-DD` (how dates are stored and sent).
DateTime parseDate(String s) {
  final p = s.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// The Indian calendar date of a recorded moment (ISO text).
String istDateOf(String isoMoment) =>
    dateOnly(DateTime.parse(isoMoment).toUtc().add(istOffset));

/// The same day [months] later, clamped to the month's last day (31 Jan + 1 = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final index = d.month - 1 + months;
  final year = d.year + index ~/ 12;
  final month = index % 12 + 1;
  final last = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, d.day > last ? last : d.day);
}

// ── who is calling ────────────────────────────────────────────────────────────

/// The roles of this system (the backend's `Role`).
class Roles {
  Roles._();
  static const villager = 'villager';
  static const gramSabha = 'gram_sabha';
  static const sdo = 'sdo';
}

/// A role held within a jurisdiction (the backend's `RoleGrant`).
class Grant {
  const Grant(this.role, {this.villageId, this.taluka, this.district});

  final String role;
  final String? villageId;
  final String? taluka;
  final String? district;

  static String _n(String? s) => (s ?? '').trim().toLowerCase();

  /// Does this role cover [village]? Village roles cover their own village; the SDO covers every
  /// village of a taluka; district roles every village of a district.
  bool covers(Map<String, dynamic> village) {
    if (role == Roles.villager || role == Roles.gramSabha) {
      return villageId == village['id'];
    }
    if (role == Roles.sdo) {
      return _n(taluka) == _n(village['taluka'] as String?) &&
          _n(district) == _n(village['district'] as String?);
    }
    return _n(district) == _n(village['district'] as String?);
  }
}

/// The person making a call, with the roles they hold today.
class Principal {
  Principal({
    required this.userId,
    required this.name,
    required this.isAdmin,
    required this.grants,
  });

  final String userId;
  final String name;
  final bool isAdmin;
  final List<Grant> grants;

  /// Roles whose jurisdiction includes [village].
  Set<String> rolesFor(Map<String, dynamic> village) =>
      {for (final g in grants) if (g.covers(village)) g.role};

  bool has(Map<String, dynamic> village, [Iterable<String>? roles]) {
    final held = rolesFor(village);
    return roles == null ? held.isNotEmpty : held.intersection(roles.toSet()).isNotEmpty;
  }

  Set<String> get roles => {for (final g in grants) g.role};
}

// ── the in-memory database ────────────────────────────────────────────────────

/// The demo's whole database: named tables (lists of JSON maps) inside one JSON-serialisable map,
/// kept on the phone between runs. Slices keep their own tables here.
class DemoDb {
  DemoDb(this.data, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Map<String, dynamic> data;
  final DateTime Function() _clock;
  static const Uuid _uuid = Uuid();

  /// The current moment (UTC). Tests may pass their own clock.
  DateTime now() => _clock().toUtc();
  String nowIso() => now().toIso8601String();

  /// Today's date in India, `YYYY-MM-DD`.
  String todayIst() => dateOnly(now().add(istOffset));

  String newId() => _uuid.v4();

  /// A table: a list of maps. Created empty on first use.
  List<Map<String, dynamic>> table(String name) {
    final raw = data.putIfAbsent(name, () => <dynamic>[]);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  /// A keyed section (a map of maps) for things looked up by one key, such as forms by case id.
  Map<String, dynamic> section(String name) =>
      (data.putIfAbsent(name, () => <String, dynamic>{}) as Map).cast<String, dynamic>();

  Map<String, dynamic>? byId(String tableName, String? id) {
    if (id == null) return null;
    for (final row in table(tableName)) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  Map<String, dynamic>? findOne(String tableName, bool Function(Map<String, dynamic>) test) {
    for (final row in table(tableName)) {
      if (test(row)) return row;
    }
    return null;
  }

  List<Map<String, dynamic>> where(
    String tableName,
    bool Function(Map<String, dynamic>) test,
  ) =>
      [for (final row in table(tableName)) if (test(row)) row];

  /// Add [row] (an `id` and the two timestamps are filled in when missing) and return it.
  Map<String, dynamic> add(String tableName, Map<String, dynamic> row) {
    row.putIfAbsent('id', newId);
    row.putIfAbsent('created_at', nowIso);
    row.putIfAbsent('updated_at', () => row['created_at']);
    table(tableName).add(row);
    return row;
  }

  /// Mark [row] as changed now.
  void touch(Map<String, dynamic> row) => row['updated_at'] = nowIso();
}

// ── requests and routes ───────────────────────────────────────────────────────

class DemoRequest {
  DemoRequest({
    required this.method,
    required this.path,
    required this.params,
    required this.query,
    required this.body,
    required this.db,
    required this.principal,
  });

  final String method;
  final String path;

  /// Path variables, e.g. `{case_id}`.
  final Map<String, String> params;
  final Map<String, List<String>> query;
  final Object? body;
  final DemoDb db;

  /// Null when the call carried no (valid) sign-in.
  final Principal? principal;

  /// The signed-in person, or 401 like the real server.
  Principal get who {
    final p = principal;
    if (p == null) throw DemoError(401, 'NOT_AUTHENTICATED', 'auth.required');
    return p;
  }

  /// The body as a map ({} when there is none).
  Map<String, dynamic> get json =>
      body is Map ? Map<String, dynamic>.from(body as Map) : <String, dynamic>{};

  String? q(String name) => query[name]?.firstOrNull;
}

typedef DemoHandler = FutureOr<dynamic> Function(DemoRequest r);

class _Route {
  _Route(this.method, this.pattern, this.handler)
      : names = RegExp(r'\{(\w+)\}').allMatches(pattern).map((m) => m.group(1)!).toList(),
        regex = RegExp(
          '^${pattern.replaceAllMapped(RegExp(r'\{\w+\}'), (_) => '([^/]+)')}\$',
        );

  final String method;
  final String pattern;
  final DemoHandler handler;
  final List<String> names;
  final RegExp regex;
}

/// Routes by method and path pattern (`/cases/{case_id}/form-a`).
class DemoRouter {
  final List<_Route> _routes = [];

  void add(String method, String pattern, DemoHandler handler) =>
      _routes.add(_Route(method, pattern, handler));

  void get(String pattern, DemoHandler h) => add('GET', pattern, h);
  void post(String pattern, DemoHandler h) => add('POST', pattern, h);
  void put(String pattern, DemoHandler h) => add('PUT', pattern, h);
  void patch(String pattern, DemoHandler h) => add('PATCH', pattern, h);
  void delete(String pattern, DemoHandler h) => add('DELETE', pattern, h);

  /// The handler and path variables for a call, or null if no route matches.
  ({DemoHandler handler, Map<String, String> params})? match(String method, String path) {
    for (final r in _routes) {
      if (r.method != method) continue;
      final m = r.regex.firstMatch(path);
      if (m == null) continue;
      return (
        handler: r.handler,
        params: {
          for (var i = 0; i < r.names.length; i++) r.names[i]: Uri.decodeComponent(m.group(i + 1)!),
        },
      );
    }
    return null;
  }
}

/// Places where one slice of the demo asks another for something. A slice that provides it sets
/// the function when its routes are registered; until then these do nothing.
class DemoHooks {
  DemoHooks._();

  /// The empty form a new case starts with (`form_a`, `form_b` or `form_c` map) for [claimType].
  static Map<String, dynamic> Function(String claimType, String userId) newForm =
      (claimType, userId) => {'claimant_names': <dynamic>[], 'updated_by_user_id': userId};

  /// Called when a claim is first filed (the written acknowledgement, Rule 11(3)).
  static void Function(DemoDb db, Map<String, dynamic> theCase, Map<String, dynamic> village)
      onSubmit = (_, __, ___) {};

  /// What the Gram Sabha still needs before it may approve [theCase]; empty = nothing missing.
  /// Each item is the backend's `{id, ok, rule, message_key, ...}` map, only the missing ones.
  static List<Map<String, dynamic>> Function(DemoDb db, Map<String, dynamic> theCase)
      approvalMissing = (_, __) => const [];

  /// Called for every workflow event, to extend the village's tamper-evident chain.
  static void Function(DemoDb db, String gramSabhaId, Map<String, dynamic> event) ledgerAppend =
      (_, __, ___) {};
}
