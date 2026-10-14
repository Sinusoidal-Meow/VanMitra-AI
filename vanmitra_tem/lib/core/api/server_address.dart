import 'package:hive_flutter/hive_flutter.dart';

import '../../data/local/hive_database.dart';
import 'api_endpoints.dart';

/// Where this phone's copy of the app finds the VanMitra server.
///
/// A demo APK is installed on phones the team never touches again, so the address must not need a
/// rebuild: it can be typed on the sign-in screen, is kept on the phone, and wins over the address
/// compiled in with `--dart-define=VANMITRA_API_BASE_URL`. Not a secret (a public web address), so
/// plain storage is fine.
class ServerAddress {
  ServerAddress._();

  static const String _key = 'server_address';

  /// Call once at start-up, after Hive is open.
  static void load() {
    final saved = Hive.box(HiveDatabase.settingsBox).get(_key);
    ApiEndpoints.serverOverride = saved is String && saved.isNotEmpty ? saved : null;
  }

  /// Keep [raw] as the server address, or forget the saved one when it is null or empty.
  static Future<void> save(String? raw) async {
    final box = Hive.box(HiveDatabase.settingsBox);
    final clean = raw == null ? '' : normalise(raw);
    if (clean.isEmpty) {
      await box.delete(_key);
      ApiEndpoints.serverOverride = null;
    } else {
      await box.put(_key, clean);
      ApiEndpoints.serverOverride = clean;
    }
  }

  /// What was typed, as a clean root address: scheme added (https unless it is a local or private
  /// address), no spaces, no trailing slash, no `/api/v1`. Empty stays empty.
  static String normalise(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (!s.contains('://')) {
      s = '${_isLocal(s) ? 'http' : 'https'}://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('/api/v1')) {
      s = s.substring(0, s.length - '/api/v1'.length);
    }
    return s;
  }

  static bool _isLocal(String s) {
    final host = s.split('/').first.split(':').first;
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host.startsWith('192.168.') ||
        host.startsWith('10.');
  }

  /// The host part, for showing on screen ("vanmitra.up.railway.app").
  static String describe(String root) {
    final uri = Uri.tryParse(root);
    return uri == null || uri.host.isEmpty ? root : uri.host + (uri.hasPort ? ':${uri.port}' : '');
  }
}
