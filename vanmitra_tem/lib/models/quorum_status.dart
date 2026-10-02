import 'gram_sabha_meeting.dart';

/// Computed quorum status for a Gram Sabha meeting
/// Implements: Q_valid = 1 if (A/R ≥ 0.5) AND (W/A ≥ 1/3), else 0
class QuorumStatus {
  final int totalRegistered;          // R: registered adult members
  final int totalPresent;             // A: verified attendees
  final int womenPresent;             // W: verified women attendees
  final int stPresent;                // ST members present
  final int pvtgPresent;              // PVTG members present
  final int otfdPresent;              // Other Traditional Forest Dwellers
  final int menPresent;

  final MeetingType meetingType;

  const QuorumStatus({
    required this.totalRegistered,
    required this.totalPresent,
    required this.womenPresent,
    required this.stPresent,
    required this.pvtgPresent,
    this.otfdPresent = 0,
    required this.menPresent,
    required this.meetingType,
  });

  // ── Computed percentages ─────────────────────────────

  double get attendancePercentage =>
      totalRegistered > 0 ? (totalPresent / totalRegistered) * 100 : 0.0;

  double get womenPercentage =>
      totalPresent > 0 ? (womenPresent / totalPresent) * 100 : 0.0;

  double get stPercentage =>
      totalPresent > 0 ? (stPresent / totalPresent) * 100 : 0.0;

  double get pvtgPercentage =>
      totalPresent > 0 ? (pvtgPresent / totalPresent) * 100 : 0.0;

  // ── Threshold checks ─────────────────────────────────

  /// A/R ≥ 0.5 (50% attendance threshold)
  bool get attendanceThresholdMet =>
      totalRegistered > 0 && (totalPresent / totalRegistered) >= 0.50;

  /// W/A ≥ 1/3 (33.33% women threshold)
  bool get womenThresholdMet =>
      totalPresent > 0 && (womenPresent / totalPresent) >= (1.0 / 3.0);

  /// ST members are present (for consent resolutions)
  bool get stRepresentationAdequate => stPresent > 0;

  /// PVTG members are present (for consent resolutions in PVTG areas)
  bool get pvtgRepresentationAdequate => pvtgPresent > 0;

  // ── Overall validity ─────────────────────────────────

  /// Standard quorum: Q_valid = 1 if (A/R ≥ 0.5) AND (W/A ≥ 1/3)
  bool get isStandardQuorumValid =>
      attendanceThresholdMet && womenThresholdMet;

  /// Enhanced quorum for consent resolutions:
  /// Standard quorum PLUS ST representation PLUS PVTG presence
  bool get isEnhancedQuorumValid =>
      isStandardQuorumValid &&
      stRepresentationAdequate &&
      pvtgRepresentationAdequate;

  /// Overall validity based on meeting type
  bool get isValid {
    if (meetingType.requiresEnhancedQuorum) {
      return isEnhancedQuorumValid;
    }
    return isStandardQuorumValid;
  }

  /// List of specific violations (what's missing)
  List<String> get violations {
    final v = <String>[];
    if (!attendanceThresholdMet) {
      v.add(
        'Attendance ${attendancePercentage.toStringAsFixed(1)}% — '
        'need ≥50% ($totalPresent/$totalRegistered)',
      );
    }
    if (!womenThresholdMet) {
      v.add(
        'Women ${womenPercentage.toStringAsFixed(1)}% — '
        'need ≥33.3% ($womenPresent/$totalPresent)',
      );
    }
    if (meetingType.requiresEnhancedQuorum) {
      if (!stRepresentationAdequate) {
        v.add('No ST members present — required for consent resolution');
      }
      if (!pvtgRepresentationAdequate) {
        v.add('No PVTG members present — required for consent resolution');
      }
    }
    return v;
  }

  /// Human-readable summary
  String get summaryEn {
    final status = isValid ? '✅ QUORUM VALID' : '❌ QUORUM NOT MET';
    return '$status | Present: $totalPresent/$totalRegistered '
        '(${attendancePercentage.toStringAsFixed(1)}%) | '
        'Women: $womenPresent/$totalPresent '
        '(${womenPercentage.toStringAsFixed(1)}%)';
  }

  Map<String, dynamic> toJson() => {
    'totalRegistered': totalRegistered,
    'totalPresent': totalPresent,
    'womenPresent': womenPresent,
    'stPresent': stPresent,
    'pvtgPresent': pvtgPresent,
    'otfdPresent': otfdPresent,
    'menPresent': menPresent,
    'meetingType': meetingType.name,
    'isValid': isValid,
    'attendancePercentage': attendancePercentage,
    'womenPercentage': womenPercentage,
  };
}
