/// Quorum of a Gram Sabha meeting [Rule 4(2)] (BR-03), ported from backend app/domain/quorum.py.
/// Three tests, all must pass:
///
///     t1  present           >= ceil(registered / 2)
///     t2  women present     >= ceil(present / 3)
///     t3  claimants present >= ceil(claimants / 2)    (resolutions on claims only)
///
/// The inputs and the result are stored with the resolution and never recomputed.
/// Pure: no database, no clock.
class QuorumResult {
  const QuorumResult({
    required this.registered,
    required this.present,
    required this.womenPresent,
    required this.claimantsTotal,
    required this.claimantsPresent,
    required this.requiredPresent,
    required this.requiredWomen,
    required this.requiredClaimants,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.passed,
    required this.failures,
  });

  final int registered;
  final int present;
  final int womenPresent;
  final int claimantsTotal;
  final int claimantsPresent;
  final int requiredPresent;
  final int requiredWomen;
  final int requiredClaimants;
  final bool t1;
  final bool t2;
  final bool t3;
  final bool passed;

  /// Message keys of the tests that failed.
  final List<String> failures;

  /// The backend's `QuorumOut` (and the `quorum_proof` stored with a resolution).
  Map<String, dynamic> proof() => {
        'registered': registered,
        'present': present,
        'women_present': womenPresent,
        'claimants_total': claimantsTotal,
        'claimants_present': claimantsPresent,
        'required_present': requiredPresent,
        'required_women': requiredWomen,
        'required_claimants': requiredClaimants,
        't1': t1,
        't2': t2,
        't3': t3,
        'passed': passed,
        'failures': List<String>.of(failures),
      };
}

/// `ceil(n / 2)` for a count (never negative).
int _ceilDiv(int n, int d) => n <= 0 ? 0 : (n + d - 1) ~/ d;

QuorumResult quorum({
  required int registered,
  required int present,
  required int womenPresent,
  int claimantsTotal = 0,
  int claimantsPresent = 0,
}) {
  final requiredPresent = _ceilDiv(registered, 2);
  final requiredWomen = _ceilDiv(present, 3);
  final requiredClaimants = _ceilDiv(claimantsTotal, 2);
  final t1 = registered > 0 && present >= requiredPresent;
  final t2 = present > 0 && womenPresent >= requiredWomen;
  final t3 = claimantsPresent >= requiredClaimants;
  final failures = <String>[
    if (!t1) 'quorum.t1_present',
    if (!t2) 'quorum.t2_women',
    if (!t3) 'quorum.t3_claimants',
  ];
  return QuorumResult(
    registered: registered,
    present: present,
    womenPresent: womenPresent,
    claimantsTotal: claimantsTotal,
    claimantsPresent: claimantsPresent,
    requiredPresent: requiredPresent,
    requiredWomen: requiredWomen,
    requiredClaimants: requiredClaimants,
    t1: t1,
    t2: t2,
    t3: t3,
    passed: failures.isEmpty,
    failures: failures,
  );
}
