import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ask_repository.dart';
import '../data/error_mapping.dart';
import '../models/ask.dart';
import 'livelihood_providers.dart';

final askConsentStoreProvider = Provider<AskConsentStore>(
  (ref) => CacheAskConsentStore(ref.watch(livelihoodCacheProvider)),
);

final askRepositoryProvider = Provider<AskRepository>(
  (ref) => RemoteAskRepository(ref.watch(livelihoodApiProvider)),
);

class AskState {
  const AskState({
    this.turns = const [],
    this.chips = const [],
    this.hasReport = false,
    this.aiAvailable = false,
    this.aiConsent,
    this.loading = false,
    this.busy = false,
    this.errorKey,
  });

  final List<ChatTurn> turns;
  final List<SuggestedQuestion> chips;
  final bool hasReport;

  /// The server has the AI step on.
  final bool aiAvailable;

  /// Whether he has allowed the AI assistant to see his report's facts; null = not asked yet.
  final bool? aiConsent;

  /// Loading the history when the screen opens.
  final bool loading;

  /// A question is on its way.
  final bool busy;

  /// The string key of a plain-language problem ("No internet right now"), or null.
  final String? errorKey;

  AskState copyWith({
    List<ChatTurn>? turns,
    List<SuggestedQuestion>? chips,
    bool? hasReport,
    bool? aiAvailable,
    bool? aiConsent,
    bool? loading,
    bool? busy,
    String? errorKey,
    bool clearError = false,
  }) =>
      AskState(
        turns: turns ?? this.turns,
        chips: chips ?? this.chips,
        hasReport: hasReport ?? this.hasReport,
        aiAvailable: aiAvailable ?? this.aiAvailable,
        aiConsent: aiConsent ?? this.aiConsent,
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
        errorKey: clearError ? null : (errorKey ?? this.errorKey),
      );
}

class AskController extends StateNotifier<AskState> {
  AskController(this._repo, this._consent) : super(const AskState());

  final AskRepository _repo;
  final AskConsentStore _consent;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final h = await _repo.history();
      final allowed = h.aiAvailable ? await _consent.read() : null;
      state = state.copyWith(
        turns: h.turns,
        chips: h.chips,
        hasReport: h.hasReport,
        aiAvailable: h.aiAvailable,
        aiConsent: allowed,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, errorKey: errorMessageKey(e));
    }
  }

  /// Send a typed question or tap a suggestion. Nothing is added to the conversation unless the
  /// server answered: a failure shows its message and keeps what he had.
  Future<bool> send(
      {String? question, String? chip, required String lang}) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final reply = await _repo.ask(
        question: question,
        chip: chip,
        lang: lang,
        // the AI assistant sees his report's facts only if he said yes, and only when it is on
        aiConsent: state.aiAvailable && state.aiConsent == true,
      );
      state = state.copyWith(
        turns: [...state.turns, reply.turn],
        chips: reply.chips,
        hasReport: true,
        busy: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, errorKey: errorMessageKey(e));
      return false;
    }
  }

  /// He answered "may the AI assistant see the facts of my report?" Kept on the phone.
  Future<void> setAiConsent(bool allowed) async {
    await _consent.write(allowed);
    state = state.copyWith(aiConsent: allowed);
  }

  /// Delete his questions (rule L8): on the server first, then on screen.
  Future<void> clear() async {
    try {
      await _repo.clear();
      state = state.copyWith(turns: const [], clearError: true);
    } catch (e) {
      state = state.copyWith(errorKey: errorMessageKey(e));
    }
  }
}

final askProvider = StateNotifierProvider.autoDispose<AskController, AskState>(
  (ref) => AskController(
    ref.watch(askRepositoryProvider),
    ref.watch(askConsentStoreProvider),
  ),
);
