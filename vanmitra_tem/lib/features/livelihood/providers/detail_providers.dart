import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/schemes_repository.dart';
import '../models/scheme.dart';
import 'livelihood_providers.dart';

final schemesRepositoryProvider = Provider<SchemesRepository>(
  (ref) => RemoteSchemesRepository(ref.watch(livelihoodApiProvider)),
);

/// The scheme register for a filter. Fetched fresh each time the screen opens.
final schemesProvider =
    FutureProvider.autoDispose.family<SchemesResult, SchemeFilter>(
  (ref, filter) => ref.watch(schemesRepositoryProvider).schemes(filter),
);

/// One idea in detail, from his current report.
final ideaDetailProvider =
    FutureProvider.autoDispose.family<IdeaDetail, String>(
  (ref, code) => ref.watch(schemesRepositoryProvider).idea(code),
);

/// Opens an official page in the phone's browser. Only https links are ever opened. Tests
/// override this so no real browser is needed.
final urlOpenerProvider = Provider<Future<bool> Function(String url)>(
  (ref) => (url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);
