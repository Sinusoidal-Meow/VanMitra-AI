import '../../../core/api/api_client.dart';
import 'livelihood_api.dart';
import '../models/profile.dart';
import 'livelihood_cache.dart';

/// Where his saved details live. Module 3 adds the server and the phone's encrypted storage
/// behind this same interface, so no screen changed.
abstract class ProfileRepository {
  Future<LivelihoodProfile?> load();
  Future<void> save(LivelihoodProfile profile);

  /// Delete his answers (rule L8). Deleting nothing is not an error.
  Future<void> delete();

  /// True while something he did is saved on the phone but not yet on the server.
  bool get pendingSync;
}

class MemoryProfileRepository implements ProfileRepository {
  LivelihoodProfile? _profile;

  @override
  Future<LivelihoodProfile?> load() async => _profile;

  @override
  Future<void> save(LivelihoodProfile profile) async => _profile = profile;

  @override
  Future<void> delete() async => _profile = null;

  @override
  bool get pendingSync => false;
}

/// Offline first (the host's rule): what he does is saved on the phone at once and never lost,
/// then sent to the server when it can be. Two things must eventually reach the server:
/// a changed profile (`dirty`) and, above all, a DELETE (`delete_pending`), because deleting his
/// answers is a promise (rule L8).
class OfflineFirstProfileRepository implements ProfileRepository {
  OfflineFirstProfileRepository(this._api, this._cache);

  final LivelihoodApi _api;
  final LivelihoodCache _cache;
  bool _pending = false;

  static const _path = '/livelihood/profile';

  @override
  bool get pendingSync => _pending;

  /// A failure that means "try again later", not "the server said no".
  bool _isTransient(Object e) =>
      e is NetworkException || (e is ApiException && e.statusCode >= 500);

  Future<LivelihoodProfile?> _local() async {
    final json = await _cache.readJson(LivelihoodCache.profileKey);
    return json == null ? null : LivelihoodProfile.fromJson(json);
  }

  @override
  Future<LivelihoodProfile?> load() async {
    // 1. a delete he asked for must reach the server before anything else
    if (await _cache.flag(LivelihoodCache.deletePendingKey)) {
      try {
        await _api.delete(_path);
        await _cache.setFlag(LivelihoodCache.deletePendingKey, false);
      } catch (e) {
        if (!_isTransient(e)) rethrow;
        _pending = true;
        return null; // he deleted it: show nothing, and keep trying
      }
    }
    // 2. changes made offline go up next
    if (await _cache.flag(LivelihoodCache.profileDirtyKey)) {
      final local = await _local();
      if (local != null) {
        try {
          await _api.put(_path, body: local.toJson());
          await _cache.setFlag(LivelihoodCache.profileDirtyKey, false);
        } catch (e) {
          if (!_isTransient(e)) rethrow;
          _pending = true;
          return local;
        }
      }
    }
    // 3. the server is the truth whenever it can be reached
    try {
      final raw = await _api.get(_path) as Map<String, dynamic>;
      final profileJson = raw['profile'] as Map<String, dynamic>;
      final profile = LivelihoodProfile.fromJson(profileJson);
      await _cache.writeJson(LivelihoodCache.profileKey, profile.toJson());
      _pending = false;
      return profile;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        await _cache
            .clearPersonal(); // nothing saved on the server, so nothing here either
        _pending = false;
        return null;
      }
      if (!_isTransient(e)) rethrow;
    } on NetworkException {
      // fall through to what is on the phone
    }
    return _local();
  }

  @override
  Future<void> save(LivelihoodProfile profile) async {
    final previous = await _cache.readJson(LivelihoodCache.profileKey);
    await _cache.writeJson(
      LivelihoodCache.profileKey,
      profile.toJson(),
    ); // saved on the phone first
    await _cache.setFlag(LivelihoodCache.profileDirtyKey, true);
    await _cache.setFlag(
      LivelihoodCache.deletePendingKey,
      false,
    ); // saving again cancels a delete
    try {
      await _api.put(_path, body: profile.toJson());
      await _cache.setFlag(LivelihoodCache.profileDirtyKey, false);
      _pending = false;
    } catch (e) {
      if (_isTransient(e)) {
        _pending = true; // kept on the phone; it goes up on the next load
        return;
      }
      // the server refused it (for example a place outside Maharashtra): do not keep it
      if (previous == null) {
        await _cache.remove(LivelihoodCache.profileKey);
      } else {
        await _cache.writeJson(LivelihoodCache.profileKey, previous);
      }
      await _cache.setFlag(LivelihoodCache.profileDirtyKey, false);
      rethrow;
    }
  }

  @override
  Future<void> delete() async {
    await _cache.clearPersonal(); // gone from the phone immediately
    await _cache.setFlag(LivelihoodCache.deletePendingKey, true);
    try {
      await _api.delete(_path);
      await _cache.setFlag(LivelihoodCache.deletePendingKey, false);
      _pending = false;
    } catch (_) {
      // offline, a server fault, or not signed in: either way keep the promise and retry on the
      // next load. His answers are already gone from the phone.
      _pending = true;
    }
  }
}
