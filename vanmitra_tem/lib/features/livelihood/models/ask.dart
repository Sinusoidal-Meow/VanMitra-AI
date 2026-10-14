// The Ask box (docs/to_do.md stage 2). Like the report, an answer is {key, params} reasons, so
// it is written in the language he has chosen now, and one saved earlier changes language with
// him. The app never decides what is allowed: the server's safety check and number check run
// first, and the app only shows the kind of answer it is told.

import 'report.dart';

/// What sort of reply this is. Red is used ONLY for [refusedHarmful].
enum AnswerKind { answer, refusedHarmful, offTopic, notInReport }

AnswerKind _kind(Object? raw) => switch (raw) {
      'ANSWER' => AnswerKind.answer,
      'REFUSED_HARMFUL' => AnswerKind.refusedHarmful,
      'OFF_TOPIC' => AnswerKind.offTopic,
      // anything we do not know is shown as the safe grey "not in your report"
      _ => AnswerKind.notInReport,
    };

class Answer {
  const Answer({
    required this.kind,
    required this.topic,
    required this.headline,
    this.items = const [],
    this.fromParts = const [],
    this.text,
    this.engine = 'template',
    this.isSampleData = false,
  });

  final AnswerKind kind;
  final String topic;
  final Reason headline;
  final List<Reason> items;

  /// Which part of the report it came from ("summary", "ideas" ...), for the "From:" line.
  final List<String> fromParts;

  /// Free text, only ever sent by the AI step (and only after the server's number check).
  final String? text;

  /// "template" (written by our own code from the report) or "ai" (an AI assistant wrote the
  /// words; the server checked every number in them against the report).
  final String engine;
  final bool isSampleData;

  bool get isAi => engine == 'ai' && text != null;

  factory Answer.fromJson(Map<String, dynamic> j) => Answer(
        kind: _kind(j['kind']),
        topic: (j['topic'] as String?) ?? 'none',
        headline:
            Reason.fromJson(Map<String, dynamic>.from(j['headline'] as Map)),
        items: [
          for (final i in (j['items'] as List? ?? const []))
            Reason.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
        fromParts: [
          for (final p in (j['from_parts'] as List? ?? const [])) '$p',
        ],
        text: j['text'] as String?,
        engine: (j['engine'] as String?) ?? 'template',
        isSampleData: j['is_sample_data'] == true,
      );
}

class ChatTurn {
  const ChatTurn({
    required this.id,
    required this.answer,
    this.question,
    this.chip,
  });

  final String id;

  /// What he typed; null when he tapped a suggestion.
  final String? question;
  final String? chip;
  final Answer answer;

  factory ChatTurn.fromJson(Map<String, dynamic> j) => ChatTurn(
        id: j['id'] as String,
        question: j['question'] as String?,
        chip: j['chip'] as String?,
        answer: Answer.fromJson(Map<String, dynamic>.from(j['answer'] as Map)),
      );
}

/// A suggested question made from facts in HIS report.
class SuggestedQuestion {
  const SuggestedQuestion(this.id, this.label);

  final String id;
  final Reason label;

  factory SuggestedQuestion.fromJson(Map<String, dynamic> j) =>
      SuggestedQuestion(
        j['id'] as String,
        Reason.fromJson(Map<String, dynamic>.from(j['label'] as Map)),
      );
}

List<SuggestedQuestion> _chips(Object? raw) => [
      for (final c in (raw as List? ?? const []))
        SuggestedQuestion.fromJson(Map<String, dynamic>.from(c as Map)),
    ];

class AskReply {
  const AskReply(this.turn, this.chips);

  final ChatTurn turn;
  final List<SuggestedQuestion> chips;

  factory AskReply.fromJson(Map<String, dynamic> j) => AskReply(
        ChatTurn.fromJson(Map<String, dynamic>.from(j['turn'] as Map)),
        _chips(j['chips']),
      );
}

class AskHistory {
  const AskHistory({
    this.turns = const [],
    this.chips = const [],
    this.hasReport = false,
    this.aiAvailable = false,
  });

  final List<ChatTurn> turns;
  final List<SuggestedQuestion> chips;
  final bool hasReport;

  /// The server has the AI step switched on, so the app may ask his permission to use it.
  final bool aiAvailable;

  factory AskHistory.fromJson(Map<String, dynamic> j) => AskHistory(
        turns: [
          for (final t in (j['turns'] as List? ?? const []))
            ChatTurn.fromJson(Map<String, dynamic>.from(t as Map)),
        ],
        chips: _chips(j['chips']),
        hasReport: j['has_report'] == true,
        aiAvailable: j['ai_available'] == true,
      );
}
