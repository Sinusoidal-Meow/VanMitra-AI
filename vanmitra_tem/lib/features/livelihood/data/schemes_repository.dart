import '../models/scheme.dart';
import 'livelihood_api.dart';

/// The one door the idea-detail and Schemes screens use. Both come from the server (the detail is
/// built from his own report there), so with no network there is nothing to show but a plain
/// "no internet" message.
abstract class SchemesRepository {
  /// The scheme register, filtered. `null` filters mean "all".
  Future<SchemesResult> schemes(SchemeFilter filter);

  /// One idea in detail, from his current report.
  Future<IdeaDetail> idea(String code);
}

class RemoteSchemesRepository implements SchemesRepository {
  RemoteSchemesRepository(this._api);

  final LivelihoodApi _api;

  @override
  Future<SchemesResult> schemes(SchemeFilter filter) async {
    final query = <String>[
      if (filter.help != null) 'help=${Uri.encodeQueryComponent(filter.help!)}',
      if (filter.audience != null)
        'audience=${Uri.encodeQueryComponent(filter.audience!)}',
    ];
    final path =
        '/livelihood/schemes${query.isEmpty ? '' : '?${query.join('&')}'}';
    final raw = await _api.get(path) as Map<String, dynamic>;
    return SchemesResult.fromJson(raw);
  }

  @override
  Future<IdeaDetail> idea(String code) async {
    final raw = await _api.get(
      '/livelihood/ideas/${Uri.encodeComponent(code)}',
    ) as Map<String, dynamic>;
    return IdeaDetail.fromJson(raw);
  }
}

/// For the standalone demo with no server.
class OfflineSchemesRepository implements SchemesRepository {
  const OfflineSchemesRepository();

  @override
  Future<SchemesResult> schemes(SchemeFilter filter) =>
      Future.error(const NetworkException());

  @override
  Future<IdeaDetail> idea(String code) =>
      Future.error(const NetworkException());
}
