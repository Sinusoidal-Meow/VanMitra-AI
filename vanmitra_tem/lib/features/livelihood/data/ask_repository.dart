import '../models/ask.dart';
import 'livelihood_api.dart';
import 'livelihood_cache.dart';

/// The one door the Ask screen uses. Every question is answered on the server (the safety check,
/// the report-only answer and the number check all live there), so there is nothing to answer
/// offline: a [NetworkException] is shown as "No internet right now".
abstract class AskRepository {
  /// Ask a typed [question] or tap a suggestion ([chip]); exactly one of them.
  ///
  /// [aiConsent] is true only if he has allowed the AI assistant to see the facts of his report.
  Future<AskReply> ask({
    String? question,
    String? chip,
    required String lang,
    bool aiConsent = false,
  });

  /// His earlier questions and answers, and the suggestions for his report.
  Future<AskHistory> history();

  /// Delete everything he asked (rule L8).
  Future<void> clear();
}

class RemoteAskRepository implements AskRepository {
  RemoteAskRepository(this._api);

  final LivelihoodApi _api;

  @override
  Future<AskReply> ask({
    String? question,
    String? chip,
    required String lang,
    bool aiConsent = false,
  }) async {
    final raw = await _api.post('/livelihood/ask', body: {
      if (question != null) 'question': question,
      if (chip != null) 'chip': chip,
      'lang': lang,
      if (aiConsent) 'ai_consent': true,
    }) as Map<String, dynamic>;
    return AskReply.fromJson(raw);
  }

  @override
  Future<AskHistory> history() async {
    final raw =
        await _api.get('/livelihood/ask/history') as Map<String, dynamic>;
    return AskHistory.fromJson(raw);
  }

  @override
  Future<void> clear() async {
    await _api.delete('/livelihood/ask/history');
  }
}

/// For the standalone demo with no server: asking needs the server, so say so plainly.
class OfflineAskRepository implements AskRepository {
  const OfflineAskRepository();

  @override
  Future<AskReply> ask({
    String? question,
    String? chip,
    required String lang,
    bool aiConsent = false,
  }) =>
      Future.error(const NetworkException());

  @override
  Future<AskHistory> history() => Future.value(const AskHistory());

  @override
  Future<void> clear() => Future.value();
}

/// Whether he has allowed the AI assistant to see the facts of his report: allowed, declined, or
/// not yet asked (null). Kept on the phone only; asked once, and he can change it any time.
abstract class AskConsentStore {
  Future<bool?> read();
  Future<void> write(bool allowed);
}

class CacheAskConsentStore implements AskConsentStore {
  CacheAskConsentStore(this._cache);

  final LivelihoodCache _cache;

  static const key = LivelihoodCache.askConsentKey;

  @override
  Future<bool?> read() async {
    final saved = await _cache.readJson(key);
    final allowed = saved?['allowed'];
    return allowed is bool ? allowed : null;
  }

  @override
  Future<void> write(bool allowed) =>
      _cache.writeJson(key, {'allowed': allowed});
}

class MemoryAskConsentStore implements AskConsentStore {
  MemoryAskConsentStore([this.value]);

  bool? value;

  @override
  Future<bool?> read() async => value;

  @override
  Future<void> write(bool allowed) async => value = allowed;
}
