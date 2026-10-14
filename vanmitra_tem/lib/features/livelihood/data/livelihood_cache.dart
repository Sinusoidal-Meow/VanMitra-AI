import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A tiny key/value store for what is kept ON THE PHONE: his last saved details and his last
/// report. Strings only, so the Hive version can be swapped for the host's own storage.
abstract class CacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class MemoryCacheStore implements CacheStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}

/// Opens the real store the first time it is needed, so providers can be built without an async
/// start-up step (the host's `main.dart` needs no change). If the encrypted box cannot be opened
/// (for example the Keystore is unavailable) it falls back to MEMORY: nothing is then kept across
/// restarts, but personal data is never written unencrypted.
class LazyCacheStore implements CacheStore {
  LazyCacheStore(this._open);

  final Future<CacheStore> Function() _open;
  Future<CacheStore>? _store;

  Future<CacheStore> get _ready =>
      _store ??= _open().catchError((_) => MemoryCacheStore() as CacheStore);

  @override
  Future<String?> read(String key) async => (await _ready).read(key);

  @override
  Future<void> write(String key, String value) async =>
      (await _ready).write(key, value);

  @override
  Future<void> remove(String key) async => (await _ready).remove(key);
}

/// The real store: an ENCRYPTED Hive box. His land and animals are personal (rule L8), so the
/// box key is generated once and kept in the Android Keystore (flutter_secure_storage), never
/// next to the data.
class HiveCacheStore implements CacheStore {
  HiveCacheStore._(this._box);

  final Box<String> _box;

  static const _boxName = 'lv_cache';
  static const _keyName = 'lv_cache_key';

  static Future<HiveCacheStore> open() async {
    await Hive.initFlutter();
    const secure = FlutterSecureStorage();
    var stored = await secure.read(key: _keyName);
    if (stored == null) {
      stored = base64UrlEncode(Hive.generateSecureKey());
      await secure.write(key: _keyName, value: stored);
    }
    final box = await Hive.openBox<String>(
      _boxName,
      encryptionCipher: HiveAesCipher(base64Url.decode(stored)),
    );
    return HiveCacheStore._(box);
  }

  @override
  Future<String?> read(String key) async => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> remove(String key) => _box.delete(key);
}

/// What is kept, and under which name. One place, so "delete my answers" can clear all of it.
class LivelihoodCache {
  LivelihoodCache(this._store);

  final CacheStore _store;

  static const profileKey = 'profile';
  static const reportKey = 'report';
  static const profileDirtyKey = 'profile_dirty';
  static const deletePendingKey = 'delete_pending';

  Future<Map<String, dynamic>?> readJson(String key) async {
    final text = await _store.read(key);
    if (text == null) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      await _store.remove(key); // a damaged entry is dropped, never shown
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      _store.write(key, jsonEncode(value));

  Future<bool> flag(String key) async => (await _store.read(key)) == '1';

  Future<void> setFlag(String key, bool on) =>
      on ? _store.write(key, '1') : _store.remove(key);

  Future<void> remove(String key) => _store.remove(key);

  /// Forget everything personal (his details and his report).
  Future<void> clearPersonal() async {
    await _store.remove(profileKey);
    await _store.remove(reportKey);
    await _store.remove(profileDirtyKey);
  }
}
