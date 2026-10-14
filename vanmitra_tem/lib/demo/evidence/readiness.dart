import '../core/demo_cases.dart';
import '../core/demo_core.dart';

/// Documentation completeness of a case, the R1-R10 checks (backend domain/readiness.py and
/// services/readiness.py). Advisory only: it never gates the workflow and is never a score.
///
/// A CFR claim gets all ten checks; an individual (Form A) or community-rights (Form B) claim
/// gets the ones that apply to it (evidence, verification, quorum, acknowledgement).

/// Rule 13 sub-clauses, the vocabulary every evidence item is tagged with (backend EvidenceRule).
const List<String> evidenceRules = [
  '13(1)(a)',
  '13(1)(b)',
  '13(1)(c)',
  '13(1)(d)',
  '13(1)(e)',
  '13(1)(f)',
  '13(1)(g)',
  '13(1)(h)',
  '13(1)(i)',
  '13(2)(a)',
  '13(2)(b)',
  '13(2)(c)',
  '13(2)(d)',
  '13(2)(e)',
];

/// How an evidence item was captured (backend EvidenceKind).
const List<String> evidenceKinds = [
  'document_scan',
  'photo',
  'gps_point',
  'satellite',
  'audio',
  'elder_statement',
  'text_note',
];

/// Rule 13(1) (general) as opposed to 13(2) (community forest resource).
bool isGeneralRule(String ruleRef) => ruleRef.startsWith('13(1)');

/// GPS and satellite output can never alone satisfy the two-evidence test (BR-06).
bool isSubstitutableKind(String kind) => kind != 'gps_point' && kind != 'satellite';

const int minGeneral = 2; // Rule 11(1)(a), 13(3)
const int minGeneralWithoutElder = 3; // R6 alternative

class ReadinessInput {
  const ReadinessInput({
    required this.claimType,
    required this.verifiedGeneral,
    required this.verifiedCfr,
    required this.signedElderStatement,
    required this.acknowledged,
    this.boundaryGsApproved = false,
    this.segmentsWithoutLandmark,
    this.verificationComplete = false,
    this.quorumPassed = false,
    this.adjacentTotal = 0,
    this.adjacentIntimated = 0,
    this.openDisputes = 0,
  });

  final String claimType;

  /// Verified, non-substitutable Rule 13(1) items (BR-06).
  final int verifiedGeneral;

  /// Verified Rule 13(2) items.
  final int verifiedCfr;

  /// A verified 13(1)(i) statement with its signed sheet.
  final bool signedElderStatement;

  /// Rule 11(3).
  final bool acknowledged;

  /// Rule 12(1)(g).
  final bool boundaryGsApproved;

  /// Null = no boundary mapped yet.
  final int? segmentsWithoutLandmark;

  /// Rule 12A(1)(2): signed or absence recorded.
  final bool verificationComplete;

  /// Rule 4(2).
  final bool quorumPassed;

  /// Bordering villages listed on Form C (item 7).
  final int adjacentTotal;

  /// Of which a G2 intimation has been dispatched.
  final int adjacentIntimated;

  /// Rule 12(3).
  final int openDisputes;
}

class CompletenessItem {
  const CompletenessItem(this.id, this.ok, this.formItem, this.rule, this.messageKey);

  final String id;
  final bool ok;
  final String formItem;
  final String rule;

  /// Translated by the app; shown when [ok] is false.
  final String messageKey;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ok': ok,
        'form_item': formItem,
        'rule': rule,
        'message_key': messageKey,
      };
}

class Completeness {
  const Completeness(this.items);

  final List<CompletenessItem> items;

  int get done => items.where((i) => i.ok).length;
  int get total => items.length;
}

Completeness readiness(ReadinessInput r) {
  var items = <CompletenessItem>[
    CompletenessItem('R1', r.verifiedGeneral >= minGeneral, 'evidence', 'Rule 11(1)(a), 13(3)',
        'readiness.r1_two_general_evidences'),
    CompletenessItem(
        'R2', r.verifiedCfr >= 1, 'evidence', 'Rule 13(2)', 'readiness.r2_cfr_evidence'),
    CompletenessItem(
        'R3', r.boundaryGsApproved, 'map', 'Rule 12(1)(g)', 'readiness.r3_boundary_approved'),
    CompletenessItem('R4', r.segmentsWithoutLandmark == 0, 'map', 'Rule 12(1)(g)',
        'readiness.r4_landmark_per_segment'),
    CompletenessItem('R5', r.verificationComplete, 'verification', 'Rule 12A(1)(2)',
        'readiness.r5_field_verification'),
    CompletenessItem(
        'R6',
        r.signedElderStatement || r.verifiedGeneral >= minGeneralWithoutElder,
        'evidence',
        'Rule 13(1)(i)',
        'readiness.r6_elder_statement'),
    CompletenessItem('R7', r.quorumPassed, 'gram_sabha', 'Rule 4(2)', 'readiness.r7_quorum'),
    CompletenessItem(
        'R8',
        r.adjacentTotal > 0 && r.adjacentIntimated >= r.adjacentTotal,
        'letters',
        'Rule 11(1)(b)',
        'readiness.r8_adjoining_intimated'),
    CompletenessItem(
        'R9', r.acknowledged, 'acknowledgement', 'Rule 11(3)', 'readiness.r9_acknowledged'),
    CompletenessItem(
        'R10', r.openDisputes == 0, 'map', 'Rule 12(3)', 'readiness.r10_no_open_dispute'),
  ];
  if (r.claimType != ClaimTypes.cfr) {
    const keep = {'R1', 'R5', 'R6', 'R7', 'R9'};
    items = [for (final i in items) if (keep.contains(i.id)) i];
  }
  return Completeness(items);
}

// ── the facts, gathered from the database (services/readiness.py, procedure_facts.py) ─────

/// Reads of other slices' tables (Gram Sabha, boundary, letters). Missing tables read as empty.
class CaseFacts {
  CaseFacts._();

  /// Evidence records not superseded by a correction, oldest first.
  static List<Map<String, dynamic>> currentEvidence(DemoDb db, String caseId) {
    final rows = db.where('evidence', (e) => e['case_id'] == caseId);
    final superseded = {
      for (final r in rows)
        if (r['supersedes_id'] != null) r['supersedes_id'],
    };
    return [for (final r in rows) if (!superseded.contains(r['id'])) r];
  }

  static Set<String> verifiedIds(DemoDb db, Iterable<String> evidenceIds) {
    final ids = evidenceIds.toSet();
    return {
      for (final v in db.table('evidence_verification'))
        if (ids.contains(v['evidence_id'])) v['evidence_id'] as String,
    };
  }

  /// The members of the Gram Sabha who are claimants in the case (case_claimant).
  static Set<String> claimantMemberIds(DemoDb db, String caseId) => {
        for (final c in db.table('case_claimant'))
          if (c['case_id'] == caseId) '${c['gs_member_id']}',
      };

  /// The latest field-verification visit (highest attempt number).
  static Map<String, dynamic>? latestVerification(DemoDb db, String caseId) {
    Map<String, dynamic>? best;
    for (final v in db.table('verification_proceeding')) {
      if (v['case_id'] != caseId) continue;
      if (best == null || ((v['attempt_no'] as num?) ?? 0) > ((best['attempt_no'] as num?) ?? 0)) {
        best = v;
      }
    }
    return best;
  }

  /// Both departments signed, or their absence is recorded (BR-07).
  static bool verificationComplete(Map<String, dynamic>? v) {
    if (v == null) return false;
    final forest = v['forest_signed'] == true || v['forest_absence_recorded'] == true;
    final revenue = v['revenue_signed'] == true || v['revenue_absence_recorded'] == true;
    return forest && revenue;
  }

  /// Absent on a second visit: the Gram Sabha decision stands [Rule 12A(2)].
  static bool finalityNote(Map<String, dynamic>? v) =>
      v != null &&
      ((v['attempt_no'] as num?) ?? 0) >= 2 &&
      (v['forest_absence_recorded'] == true || v['revenue_absence_recorded'] == true) &&
      verificationComplete(v);

  /// The Gram Sabha's current resolution on the case (the last that no correction replaced).
  static Map<String, dynamic>? currentResolution(DemoDb db, String caseId) {
    final rows = db.where('resolution', (r) => r['case_id'] == caseId);
    final superseded = {
      for (final r in rows)
        if (r['supersedes_id'] != null) r['supersedes_id'],
    };
    final live = [for (final r in rows) if (!superseded.contains(r['id'])) r];
    return live.isEmpty ? null : live.last;
  }

  static Map<String, dynamic>? currentBoundary(DemoDb db, String caseId) =>
      db.findOne('cfr_boundary', (b) => b['case_id'] == caseId && b['is_current'] == true);

  static int segmentsWithoutLandmark(Map<String, dynamic> b) {
    final marked = {
      for (final lm in (b['landmarks'] as List?) ?? const []) (lm as Map)['segment_seq'],
    };
    return [
      for (final s in (b['segments'] as List?) ?? const [])
        if (!marked.contains((s as Map)['seq'])) s,
    ].length;
  }

  static bool _isOpenDispute(Map<String, dynamic> d) {
    if (d['sdlc_referral_on'] != null) return false;
    final overlap = d['overlap_ha'];
    final ha = overlap is num ? overlap : num.tryParse('$overlap') ?? 0;
    if (ha <= 0) return false;
    final outcome = d['outcome'];
    return outcome == null || outcome == 'not_resolved';
  }

  /// Open overlaps of this claim with a neighbour's claim that still stands.
  static int openDisputes(DemoDb db, String caseId) {
    var count = 0;
    for (final d in db.table('dispute')) {
      if (d['case_id'] != caseId && d['neighbour_case_id'] != caseId) continue;
      if (!_isOpenDispute(d)) continue;
      final c1 = db.byId('claim_case', d['case_id'] as String?);
      final c2 = db.byId('claim_case', d['neighbour_case_id'] as String?);
      if (c1 != null && !_closed(c1) && c2 != null && !_closed(c2)) count++;
    }
    return count;
  }

  static bool _closed(Map<String, dynamic> c) =>
      c['state'] == CaseStates.rejected || c['state'] == CaseStates.expired;

  /// The inputs of the R1-R10 checks for the case.
  static ReadinessInput input(DemoDb db, CaseCtx ctx) {
    final c = ctx.theCase;
    final caseId = c['id'] as String;
    final claimType = c['claim_type'] as String;
    final evidence = currentEvidence(db, caseId);
    final verified = verifiedIds(db, [for (final e in evidence) e['id'] as String]);
    final ok = [for (final e in evidence) if (verified.contains(e['id'])) e];
    final general = ok
        .where((e) => isGeneralRule('${e['rule_ref']}') && e['is_substitutable'] == true)
        .length;
    final cfr = ok
        .where((e) => !isGeneralRule('${e['rule_ref']}') && e['is_substitutable'] == true)
        .length;
    final elder = ok.any(
      (e) => e['kind'] == 'elder_statement' && e['signed_scan_media_id'] != null,
    );

    var adjacentTotal = 0;
    var adjacentIntimated = 0;
    final formC = c['form_c'];
    if (claimType == ClaimTypes.cfr && formC is Map) {
      final names = {
        for (final b in (formC['bordering_villages'] as List?) ?? const [])
          '${(b as Map)['name'] ?? ''}'.trim().toLowerCase(),
      };
      adjacentTotal = names.length;
      final sent = {
        for (final l in db.table('correspondence'))
          if (l['gram_sabha_id'] == c['gram_sabha_id'] &&
              l['template'] == 'g2_intimation_adjoining' &&
              l['dispatched_on'] != null)
            '${l['neighbour_village'] ?? ''}'.trim().toLowerCase(),
      };
      adjacentIntimated = names.intersection(sent).length;
    }

    var approved = false;
    int? unmarked;
    var disputes = 0;
    final resolution = currentResolution(db, caseId);
    final quorumProof = resolution?['quorum_proof'];
    final verifiedVisit = verificationComplete(latestVerification(db, caseId));
    if (claimType == ClaimTypes.cfr) {
      final b = currentBoundary(db, caseId);
      if (b != null) {
        approved = b['status'] == 'gs_approved' || b['status'] == 'titled';
        unmarked = segmentsWithoutLandmark(b);
      }
      disputes = openDisputes(db, caseId);
    }
    return ReadinessInput(
      claimType: claimType,
      verifiedGeneral: general,
      verifiedCfr: cfr,
      signedElderStatement: elder,
      acknowledged: c['ack_serial'] != null,
      adjacentTotal: adjacentTotal,
      adjacentIntimated: adjacentIntimated,
      boundaryGsApproved: approved,
      segmentsWithoutLandmark: unmarked,
      verificationComplete: verifiedVisit,
      quorumPassed: quorumProof is Map && quorumProof['passed'] == true,
      openDisputes: disputes,
    );
  }

  static Completeness compute(DemoDb db, CaseCtx ctx) => readiness(input(db, ctx));
}
