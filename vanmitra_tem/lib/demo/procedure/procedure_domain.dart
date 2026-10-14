import '../core/demo_core.dart';

/// Pure rules of the statutory procedure (no database, no requests), ported from the backend's
/// `domain/frc.py`, `domain/clocks.py` and `domain/dates.py`.
///
/// Dates here are UTC midnight [DateTime]s (see `parseDate` / `dateOnly` in demo_core.dart).

// ── dates ─────────────────────────────────────────────────────────────────────

/// The call for claims stays open three months [Rule 11(1)(a)].
const int claimWindowMonths = 3;

// ── Forest Rights Committee [Rule 3(1)] (BR-01) and recusal [Rule 3(3)] (BR-02) ──

/// Rule 3(1): "not less than ten but not exceeding fifteen persons as members of the Forest
/// Rights Committee, wherein at least two-thirds of the members shall be the Scheduled Tribes and
/// not less than one-third of such members shall be women; provided that where there are no
/// Scheduled Tribes, at least one-third of such members shall be women".
class FrcRules {
  FrcRules._();

  static const int minMembers = 10;
  static const int maxMembers = 15;

  static const String female = 'female';
  static const String st = 'st';

  /// The arithmetic of a proposed committee, with every failure as a message key.
  static FrcCheck check(
    List<FrcCandidate> candidates, {
    required bool gramSabhaHasSt,
    String? chairId,
    String? secretaryId,
  }) {
    final n = candidates.length;
    final stCount = candidates.where((c) => c.category == st).length;
    final women = candidates.where((c) => c.gender == female).length;
    final requiredSt = gramSabhaHasSt ? _ceilDiv(2 * n, 3) : 0;
    final requiredWomen = _ceilDiv(n, 3);
    final ids = {for (final c in candidates) c.memberId};
    final failures = <String>[];
    if (ids.length != n) failures.add('frc.duplicate_member');
    if (n < minMembers) failures.add('frc.too_few_members');
    if (n > maxMembers) failures.add('frc.too_many_members');
    if (gramSabhaHasSt && stCount < requiredSt) failures.add('frc.too_few_st');
    if (women < requiredWomen) failures.add('frc.too_few_women');
    if (chairId == null || !ids.contains(chairId)) failures.add('frc.chair_not_a_member');
    if (secretaryId == null || !ids.contains(secretaryId)) {
      failures.add('frc.secretary_not_a_member');
    }
    if (chairId != null && chairId == secretaryId) failures.add('frc.chair_and_secretary_same');
    return FrcCheck(
      ok: failures.isEmpty,
      members: n,
      st: stCount,
      women: women,
      requiredSt: requiredSt,
      requiredWomen: requiredWomen,
      stRuleApplies: gramSabhaHasSt,
      failures: failures,
    );
  }

  /// BR-02: an FRC member who is a claimant in a case may not verify that case.
  static bool mustRecuse(String? memberId, Iterable<String> claimantIds) =>
      memberId != null && claimantIds.toSet().contains(memberId);

  static int _ceilDiv(int a, int b) => (a + b - 1) ~/ b;
}

class FrcCandidate {
  const FrcCandidate(this.memberId, this.gender, this.category);

  final String memberId;

  /// `female`, `male` or `other`.
  final String gender;

  /// `st`, `otfd` or `other`.
  final String category;
}

class FrcCheck {
  const FrcCheck({
    required this.ok,
    required this.members,
    required this.st,
    required this.women,
    required this.requiredSt,
    required this.requiredWomen,
    required this.stRuleApplies,
    required this.failures,
  });

  final bool ok;
  final int members;
  final int st;
  final int women;

  /// 0 when the Gram Sabha has no Scheduled Tribe members.
  final int requiredSt;
  final int requiredWomen;
  final bool stRuleApplies;

  /// Message keys.
  final List<String> failures;

  /// The stored proof / `FrcCheckOut` body.
  Map<String, dynamic> proof() => {
        'ok': ok,
        'members': members,
        'st': st,
        'women': women,
        'required_st': requiredSt,
        'required_women': requiredWomen,
        'st_rule_applies': stRuleApplies,
        'failures': List<String>.from(failures),
      };
}

// ── statutory clocks (Spec §8) ────────────────────────────────────────────────

enum ClockStatus {
  running('running'),
  overdue('overdue'),
  met('met');

  const ClockStatus(this.value);
  final String value;
}

class StatutoryClock {
  const StatutoryClock({
    required this.kind,
    required this.rule,
    required this.startsOn,
    required this.dueOn,
    required this.status,
    required this.daysRemaining,
    required this.nextAlertOn,
  });

  final String kind;
  final String rule;
  final DateTime startsOn;
  final DateTime dueOn;
  final ClockStatus status;

  /// Negative when overdue.
  final int daysRemaining;
  final DateTime? nextAlertOn;

  /// The backend's `ClockOut`.
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'rule': rule,
        'starts_on': dateOnly(startsOn),
        'due_on': dateOnly(dueOn),
        'status': status.value,
        'days_remaining': daysRemaining,
        'next_alert_on': nextAlertOn == null ? null : dateOnly(nextAlertOn!),
      };
}

class ProcedureClocks {
  ProcedureClocks._();

  /// Against a Gram Sabha resolution [Sec 6(2), Rule 14(1)].
  static const int petitionDays = 60;
  static const int petitionExtensionDays = 30;

  /// Between Gram Sabhas [Rule 14(7)].
  static const int mutualSolutionDays = 30;

  /// After the title [Rule 12A(9)].
  static const int recordUpdateMonths = 3;

  /// Days after the start at which to remind (60-day clocks).
  static const List<int> alertDays = [30, 45, 55, 58];

  static DateTime _plusDays(DateTime d, int days) => d.add(Duration(days: days));

  static DateTime petitionDue(DateTime resolutionOn) => _plusDays(resolutionOn, petitionDays);

  static DateTime claimWindowDue(DateTime calledOn) => addMonths(calledOn, claimWindowMonths);

  static DateTime mutualSolutionDue(DateTime detectedOn) =>
      _plusDays(detectedOn, mutualSolutionDays);

  static DateTime recordUpdateDue(DateTime issuedOn) => addMonths(issuedOn, recordUpdateMonths);

  /// Where a period stands today. The due day itself is still running.
  static StatutoryClock clock(
    String kind,
    String rule,
    DateTime startsOn,
    DateTime dueOn,
    DateTime today, {
    DateTime? metOn,
    List<int> alerts = const [],
  }) {
    final ClockStatus status;
    if (metOn != null) {
      status = ClockStatus.met;
    } else if (today.isAfter(dueOn)) {
      status = ClockStatus.overdue;
    } else {
      status = ClockStatus.running;
    }
    DateTime? nextAlert;
    if (status == ClockStatus.running) {
      final upcoming = [
        for (final d in alerts)
          if (!_plusDays(startsOn, d).isBefore(today)) _plusDays(startsOn, d),
      ];
      if (upcoming.isNotEmpty) {
        nextAlert = upcoming.reduce((a, b) => a.isBefore(b) ? a : b);
      }
    }
    return StatutoryClock(
      kind: kind,
      rule: rule,
      startsOn: startsOn,
      dueOn: dueOn,
      status: status,
      daysRemaining: dueOn.difference(today).inDays,
      nextAlertOn: nextAlert,
    );
  }
}
