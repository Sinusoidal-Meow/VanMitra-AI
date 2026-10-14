import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_service.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';
import 'livelihood_providers.dart';

/// Offline first: saved on the phone at once, sent to the server when it can be. The standalone
/// demo overrides this with an in-memory one.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => OfflineFirstProfileRepository(
    ref.watch(livelihoodApiProvider),
    ref.watch(livelihoodCacheProvider),
  ),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

/// True while something he did is saved on the phone but has not reached the server yet.
final syncPendingProvider = StateProvider<bool>((ref) => false);

/// His saved details, or null if he has not added any. Synchronous so screens never flicker;
/// the repository does the saving (and the sending) behind it.
class ProfileController extends StateNotifier<LivelihoodProfile?> {
  ProfileController(this._repo, this._setPending) : super(null);

  final ProfileRepository _repo;
  final void Function(bool pending) _setPending;

  /// Load what is saved (this also sends anything that was waiting). A failure that is not
  /// "offline" (for example he is not signed in) leaves the screen as it was.
  Future<void> load() async {
    try {
      state = await _repo.load();
    } catch (_) {
      // keep showing what we have; the report screen explains sign-in and server problems
    }
    _setPending(_repo.pendingSync);
  }

  Future<void> save(LivelihoodProfile profile) async {
    await _repo.save(
      profile,
    ); // throws if the server refused it; then nothing is kept
    state = profile;
    _setPending(_repo.pendingSync);
  }

  /// Delete his answers (rule L8): gone from the screen and the phone at once; the server copy
  /// is deleted now, or as soon as there is a connection.
  Future<void> delete() async {
    await _repo.delete();
    state = null;
    _setPending(_repo.pendingSync);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileController, LivelihoodProfile?>(
  (ref) => ProfileController(
    ref.watch(profileRepositoryProvider),
    (pending) => ref.read(syncPendingProvider.notifier).state = pending,
  ),
);
