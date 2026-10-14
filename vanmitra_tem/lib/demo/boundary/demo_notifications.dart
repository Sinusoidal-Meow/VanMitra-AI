import '../core/demo_core.dart';
import 'demo_input.dart';
import 'demo_title.dart';

/// Notifications, device tokens and the title draft (backend api/v1/notifications.py,
/// devices.py, services/push.py and workflow.py's title-draft).
///
/// Tables: `notification` and `device_token` (the Python models' fields). The demo has no push
/// service: [deliver] does nothing, a message only appears in the app's list.
class DemoNotifications {
  DemoNotifications._();

  static const int maxListed = 100;

  /// Add a message for [userId] (what the backend's services do when something happens, such as
  /// a claim closing for want of a resubmission). Returns the row.
  static Map<String, dynamic> notify(
    DemoDb db, {
    required String userId,
    required String kind,
    required String titleEn,
    required String bodyEn,
    required String titleMr,
    required String bodyMr,
    String? caseId,
  }) =>
      db.add('notification', {
        'user_id': userId,
        'case_id': caseId,
        'kind': kind,
        'title_en': titleEn,
        'body_en': bodyEn,
        'title_mr': titleMr,
        'body_mr': bodyMr,
        'read_at': null,
      });

  /// services/push.py `deliver`: the demo has no phone push, so there is nothing to send.
  static int deliver(DemoDb db, Iterable<Map<String, dynamic>> notifications) => 0;

  static Map<String, dynamic> _out(Map<String, dynamic> n) => {
        'id': n['id'],
        'case_id': n['case_id'],
        'kind': n['kind'],
        'title_en': n['title_en'],
        'body_en': n['body_en'],
        'title_mr': n['title_mr'],
        'body_mr': n['body_mr'],
        'created_at': n['created_at'],
        'read': n['read_at'] != null,
      };

  static Map<String, dynamic> _page(DemoDb db, String userId) {
    final mine = db.where('notification', (n) => n['user_id'] == userId);
    // newest first; messages of the same moment keep the later one first
    final indexed = [for (var i = 0; i < mine.length; i++) (i, mine[i])];
    indexed.sort((a, b) {
      final c = '${b.$2['created_at']}'.compareTo('${a.$2['created_at']}');
      return c != 0 ? c : b.$1.compareTo(a.$1);
    });
    return {
      'unread': mine.where((n) => n['read_at'] == null).length,
      'items': [for (final e in indexed.take(maxListed)) _out(e.$2)],
    };
  }

  static const Set<String> _platforms = {'android', 'ios', 'web'};
  static const Set<String> _languages = {'mr', 'en'};

  static void register(DemoRouter r) {
    r.get('/notifications', (req) => _page(req.db, req.who.userId));

    r.post('/notifications/read-all', (req) {
      final db = req.db;
      final p = req.who;
      final now = db.nowIso();
      for (final n in db.where('notification', (n) => n['user_id'] == p.userId && n['read_at'] == null)) {
        n['read_at'] = now;
      }
      return _page(db, p.userId);
    });

    r.post('/notifications/{notification_id}/read', (req) {
      final db = req.db;
      final p = req.who;
      final n = db.byId('notification', req.params['notification_id']);
      if (n == null || n['user_id'] != p.userId) {
        throw DemoError(404, 'NOTIFICATION_NOT_FOUND', 'notification.not_found');
      }
      n['read_at'] ??= db.nowIso();
      return _out(n);
    });

    // Register (or refresh) this phone for the signed-in user. A phone signed in by another user
    // before is moved to this user.
    r.post('/devices', (req) {
      final db = req.db;
      final p = req.who;
      final c = Check(req.body);
      final body = c.root ?? <String, dynamic>{};
      final token = c.text(body, 'token', required: true, min: 20, max: 4096);
      final platform = c.choice(body, 'platform', _platforms, fallback: 'android');
      final language = c.choice(body, 'language', _languages, fallback: 'mr');
      c.done();

      var device = db.findOne('device_token', (d) => d['token'] == token);
      if (device == null) {
        device = db.add('device_token', {
          'user_id': p.userId,
          'token': token,
          'platform': platform,
          'language': language,
        });
      } else {
        device['user_id'] = p.userId;
        device['platform'] = platform;
        device['language'] = language;
        device['updated_at'] = db.nowIso();
      }
      return {'token': device['token'], 'platform': device['platform'], 'language': device['language']};
    });

    // Stop push messages to this phone (on sign-out). Unknown tokens are ignored.
    r.delete('/devices/{token}', (req) {
      final db = req.db;
      final p = req.who;
      db.table('device_token').removeWhere(
            (d) => d['token'] == req.params['token'] && d['user_id'] == p.userId,
          );
      return null;
    });

    DemoTitle.register(r);
  }
}
