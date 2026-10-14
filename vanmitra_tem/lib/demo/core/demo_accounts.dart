import 'demo_core.dart';

/// Accounts for the offline demo: the same five logins the real seed script makes
/// (scripts/seed_demo.py: PIN 123456), self-registration of new village users, sign-in, the
/// current user and the village list. Ported from backend api/v1/auth.py, admin.py.
class DemoAccounts {
  DemoAccounts._();

  static const String pin = '123456';
  static const String taluka = 'Jawhar';
  static const String district = 'Palghar';

  // fixed ids so a village or user means the same thing on every install
  static const String villageId = '01a11846-11fc-7894-bcb3-597768083ceb';
  static const String gramSabhaId = '01a11846-11fc-7894-bcb3-597768083cec';

  /// (phone, name, role, is_admin): scripts/seed_demo.py.
  static const List<(String, String, String?, bool)> demoUsers = [
    ('9000000001', 'Demo Village User', Roles.villager, false),
    ('9000000002', 'Demo Village User 2', Roles.villager, false),
    ('9000000003', 'Demo Gram Sabha (Ozhar)', Roles.gramSabha, false),
    ('9000000004', 'Demo Admin (back-office)', null, true),
    ('9000000005', 'Demo SDO (Jawhar)', Roles.sdo, false),
  ];

  /// Fictional members for the Form C member sheet (item 5).
  static const List<(String, String, String)> demoMembers = [
    ('Demo Member 1', 'female', 'st'),
    ('Demo Member 2', 'male', 'st'),
    ('Demo Member 3', 'female', 'st'),
    ('Demo Member 4', 'male', 'otfd'),
    ('Demo Member 5', 'female', 'other'),
  ];

  static String userIdFor(int n) => '00000000-0000-4000-8000-00000000000$n';

  /// Put the village, its Gram Sabha, its members and the five demo logins in place (once).
  static void seed(DemoDb db) {
    if (db.table('village').isNotEmpty) return;
    final now = db.nowIso();
    db.add('village', {
      'id': villageId,
      'name_mr': 'ओझर',
      'name_en': 'Ozhar',
      'gram_panchayat': 'Ozhar',
      'taluka': taluka,
      'district': district,
      'state': 'Maharashtra',
      'consolidation_status': 'recognised',
      'lgd_code': null,
      'parent_village_id': null,
      'created_at': now,
    });
    db.add('gram_sabha', {
      'id': gramSabhaId,
      'village_id': villageId,
      'chain_head_hash': null,
      'chain_length': 0,
      'created_at': now,
    });
    for (final (name, gender, category) in demoMembers) {
      db.add('gs_member', {
        'gram_sabha_id': gramSabhaId,
        'name': name,
        'gender': gender,
        'category': category,
        'active': true,
        'created_at': now,
      });
    }
    var n = 1;
    for (final (phone, name, role, admin) in demoUsers) {
      final id = userIdFor(n++);
      db.add('app_user', {
        'id': id,
        'phone': phone,
        'name': name,
        'pin': pin,
        'is_admin': admin,
        'is_active': true,
        'last_login_at': null,
        'created_at': now,
      });
      if (role != null) _grant(db, id, role);
    }
  }

  static void _grant(DemoDb db, String userId, String role) {
    db.add('user_role', {
      'user_id': userId,
      'role': role,
      'village_id': role == Roles.sdo ? null : villageId,
      'taluka': role == Roles.sdo ? taluka : null,
      'district': role == Roles.sdo ? district : null,
      'valid_from': '2026-01-01',
      'valid_to': null,
    });
  }

  // ── tokens ──────────────────────────────────────────────────────────────────

  static Map<String, dynamic> tokens(String userId) => {
        'access_token': 'demo-access-$userId',
        'refresh_token': 'demo-refresh-$userId',
        'token_type': 'bearer',
        'expires_in': 86400,
      };

  /// The user a bearer token names, or null.
  static String? userIdOfToken(String? token, {String kind = 'access'}) {
    final prefix = 'demo-$kind-';
    if (token == null || !token.startsWith(prefix)) return null;
    return token.substring(prefix.length);
  }

  /// The person behind [userId], with the roles valid today.
  static Principal? principalOf(DemoDb db, String? userId) {
    final user = db.byId('app_user', userId);
    if (user == null || user['is_active'] != true) return null;
    final today = db.todayIst();
    final grants = <Grant>[];
    for (final g in db.where('user_role', (g) => g['user_id'] == userId)) {
      final from = g['valid_from'] as String?;
      final to = g['valid_to'] as String?;
      if (from != null && from.compareTo(today) > 0) continue;
      if (to != null && to.compareTo(today) < 0) continue;
      grants.add(Grant(
        g['role'] as String,
        villageId: g['village_id'] as String?,
        taluka: g['taluka'] as String?,
        district: g['district'] as String?,
      ));
    }
    return Principal(
      userId: userId!,
      name: user['name'] as String,
      isAdmin: user['is_admin'] == true,
      grants: grants,
    );
  }

  static String levelOf(String role) => switch (role) {
        Roles.villager || Roles.gramSabha => 'village',
        Roles.sdo => 'subdivision',
        _ => 'district',
      };

  // ── routes ──────────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    r.get('/public/villages', (req) {
      final rows = [...req.db.table('village')]..sort((a, b) =>
          '${a['district']}${a['taluka']}${a['name_en']}'
              .compareTo('${b['district']}${b['taluka']}${b['name_en']}'));
      return [
        for (final v in rows)
          {
            'id': v['id'],
            'name_mr': v['name_mr'],
            'name_en': v['name_en'],
            'gram_panchayat': v['gram_panchayat'],
            'taluka': v['taluka'],
            'district': v['district'],
          },
      ];
    });

    r.post('/auth/register', (req) {
      final b = req.json;
      final name = '${b['name'] ?? ''}'.trim();
      final phone = '${b['phone'] ?? ''}';
      final pinIn = '${b['pin'] ?? ''}';
      _validate(name, phone, pinIn);
      final village = req.db.byId('village', b['village_id'] as String?);
      if (village == null) throw DemoError(422, 'VILLAGE_NOT_FOUND', 'village.not_found');
      if (req.db.findOne('app_user', (u) => u['phone'] == phone) != null) {
        throw DemoError(409, 'PHONE_ALREADY_REGISTERED', 'auth.phone_taken');
      }
      final user = req.db.add('app_user', {
        'phone': phone,
        'name': name,
        'pin': pinIn,
        'is_admin': false,
        'is_active': true,
        'last_login_at': req.db.nowIso(),
      });
      req.db.add('user_role', {
        'user_id': user['id'],
        'role': Roles.villager,
        'village_id': village['id'],
        'taluka': null,
        'district': null,
        'valid_from': req.db.todayIst(),
        'valid_to': null,
      });
      return tokens(user['id'] as String);
    });

    r.post('/auth/login', (req) {
      final b = req.json;
      final phone = '${b['phone'] ?? ''}';
      final pinIn = '${b['pin'] ?? ''}';
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone) || !RegExp(r'^\d{6}$').hasMatch(pinIn)) {
        throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid');
      }
      final user = req.db.findOne('app_user', (u) => u['phone'] == phone);
      if (user == null || user['pin'] != pinIn || user['is_active'] != true) {
        throw DemoError(401, 'INVALID_CREDENTIALS', 'auth.invalid_credentials');
      }
      user['last_login_at'] = req.db.nowIso();
      return tokens(user['id'] as String);
    });

    r.post('/auth/refresh', (req) {
      final id = userIdOfToken(req.json['refresh_token'] as String?, kind: 'refresh');
      final user = req.db.byId('app_user', id);
      if (user == null || user['is_active'] != true) {
        throw DemoError(401, 'NOT_AUTHENTICATED', 'auth.required');
      }
      return tokens(id!);
    });

    r.get('/me', (req) {
      final p = req.who;
      final user = req.db.byId('app_user', p.userId)!;
      final roles = <Map<String, dynamic>>[];
      final rows = req.db.where('user_role', (g) => g['user_id'] == p.userId)
        ..sort((a, b) => '${a['role']}'.compareTo('${b['role']}'));
      final today = req.db.todayIst();
      for (final g in rows) {
        final from = g['valid_from'] as String?;
        final to = g['valid_to'] as String?;
        if (from != null && from.compareTo(today) > 0) continue;
        if (to != null && to.compareTo(today) < 0) continue;
        final village = req.db.byId('village', g['village_id'] as String?);
        roles.add({
          'role': g['role'],
          'level': levelOf(g['role'] as String),
          'village_id': g['village_id'],
          'village_name_mr': village?['name_mr'],
          'village_name_en': village?['name_en'],
          'taluka': village?['taluka'] ?? g['taluka'],
          'district': village?['district'] ?? g['district'],
          'valid_from': g['valid_from'],
          'valid_to': g['valid_to'],
        });
      }
      return {
        'id': user['id'],
        'name': user['name'],
        'phone': user['phone'],
        'is_admin': user['is_admin'],
        'roles': roles,
      };
    });

    // back-office: create a Gram Sabha or SDO login (admin only; admin never sees claims)
    r.post('/admin/users', (req) {
      final p = req.who;
      if (!p.isAdmin) throw DemoError(403, 'FORBIDDEN', 'auth.admin_only');
      final b = req.json;
      final name = '${b['name'] ?? ''}'.trim();
      final phone = '${b['phone'] ?? ''}';
      final pinIn = '${b['pin'] ?? ''}';
      _validate(name, phone, pinIn);
      final role = '${b['role'] ?? ''}';
      String? villageId;
      String? talukaIn;
      String? districtIn;
      if (role == Roles.villager || role == Roles.gramSabha) {
        final village = req.db.byId('village', b['village_id'] as String?);
        if (village == null) throw DemoError(422, 'VILLAGE_REQUIRED', 'admin.village_required');
        villageId = village['id'] as String;
      } else if (role == Roles.sdo) {
        talukaIn = '${b['taluka'] ?? ''}'.trim();
        districtIn = '${b['district'] ?? ''}'.trim();
        if (talukaIn.isEmpty || districtIn.isEmpty) {
          throw DemoError(422, 'TALUKA_AND_DISTRICT_REQUIRED', 'admin.taluka_district_required');
        }
      } else {
        throw DemoError(422, 'UNKNOWN_ROLE', 'admin.unknown_role');
      }
      if (req.db.findOne('app_user', (u) => u['phone'] == phone) != null) {
        throw DemoError(409, 'PHONE_ALREADY_REGISTERED', 'auth.phone_taken');
      }
      final user = req.db.add('app_user', {
        'phone': phone,
        'name': name,
        'pin': pinIn,
        'is_admin': false,
        'is_active': true,
        'last_login_at': null,
      });
      req.db.add('user_role', {
        'user_id': user['id'],
        'role': role,
        'village_id': villageId,
        'taluka': talukaIn,
        'district': districtIn,
        'valid_from': req.db.todayIst(),
        'valid_to': null,
      });
      return {
        'id': user['id'],
        'name': name,
        'phone': phone,
        'role': role,
        'village_id': villageId,
        'taluka': talukaIn,
        'district': districtIn,
      };
    });

    r.get('/admin/users', (req) {
      if (!req.who.isAdmin) throw DemoError(403, 'FORBIDDEN', 'auth.admin_only');
      final out = <Map<String, dynamic>>[];
      for (final u in req.db.table('app_user')) {
        final grants = req.db.where('user_role', (g) => g['user_id'] == u['id']);
        if (grants.isEmpty) continue;
        final g = grants.first;
        out.add({
          'id': u['id'],
          'name': u['name'],
          'phone': u['phone'],
          'role': g['role'],
          'village_id': g['village_id'],
          'taluka': g['taluka'],
          'district': g['district'],
        });
      }
      return out;
    });
  }

  static void _validate(String name, String phone, String pinIn) {
    final bad = name.isEmpty ||
        name.length > 200 ||
        !RegExp(r'^[6-9]\d{9}$').hasMatch(phone) ||
        !RegExp(r'^\d{6}$').hasMatch(pinIn);
    if (bad) throw DemoError(422, 'VALIDATION_ERROR', 'validation.invalid');
  }
}
