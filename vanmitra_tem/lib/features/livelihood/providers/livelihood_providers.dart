import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../data/livelihood_api.dart';
import '../data/livelihood_cache.dart';
import '../data/livelihood_repository.dart';
import '../models/report.dart';

/// The server, through the app's ApiClient. In the host that is the host's own client (login
/// token, base URL); the standalone shell supplies its stand-in. Tests override this.
final livelihoodApiProvider =
    Provider<LivelihoodApi>((ref) => HostApiAdapter(ApiClient()));

/// What is kept on the phone: an encrypted box, opened the first time it is used.
final livelihoodCacheProvider = Provider<LivelihoodCache>(
  (ref) => LivelihoodCache(LazyCacheStore(HiveCacheStore.open)),
);

/// The default is LIVE: the server, with the last report kept on the phone as a fallback. The
/// standalone demo overrides this with the bundled SAMPLE report (see lib/shell).
final livelihoodRepositoryProvider = Provider<LivelihoodRepository>(
  (ref) => RemoteLivelihoodRepository(
    ref.watch(livelihoodApiProvider),
    ref.watch(livelihoodCacheProvider),
  ),
);

/// His report: built on the server when it can be, otherwise the last one saved on the phone.
/// Invalidate it after his details change, so the next look builds a fresh one.
final reportProvider = FutureProvider<ReportResult>(
  (ref) => ref.watch(livelihoodRepositoryProvider).report(),
);

/// Which resources the Resources screen shows. null = all.
final resourceFilterProvider = StateProvider<UsefulLabel?>((ref) => null);
