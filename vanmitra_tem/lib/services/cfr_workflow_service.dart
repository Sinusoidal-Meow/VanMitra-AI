import 'package:uuid/uuid.dart';
import '../models/cfr_claim_stage_data.dart';
import '../models/claim.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import 'signature_service.dart';

/// Result wrapper for CFR workflow state transitions
class TransitionResult {
  final bool isSuccess;
  final Claim? updatedClaim;
  final String errorMessage;

  const TransitionResult.success(this.updatedClaim)
      : isSuccess = true,
        errorMessage = '';

  const TransitionResult.failure(this.errorMessage)
      : isSuccess = false,
        updatedClaim = null;
}

/// Centralized Workflow State Machine and Permission Enforcement Service
class CfrWorkflowService {
  final ISignatureService _signatureService;

  CfrWorkflowService({ISignatureService? signatureService})
      : _signatureService = signatureService ?? SignatureService();

  // ─── 1. Submit to FRC ──────────────────────────────────────────────────
  TransitionResult submitToFrc(Claim claim, User actor) {
    if (actor.role != UserRole.villager && actor.role != UserRole.admin) {
      return const TransitionResult.failure(
          'Only Village Users or Admins can submit claims to the FRC.');
    }
    if (claim.status != ClaimStatus.draft) {
      return TransitionResult.failure(
          'Claim must be in DRAFT state to submit to FRC (Current: ${claim.status.displayNameEn}).');
    }

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: 'SUBMITTED_TO_FRC',
      previousState: claim.status.name,
      newState: ClaimStatus.submittedToFrc.name,
      comment: 'Claim submitted to Forest Rights Committee for investigation.',
    );

    final updated = claim.copyWith(
      status: ClaimStatus.submittedToFrc,
      assignedAuthority: UserRole.frc,
      submittedAt: DateTime.now(),
      auditTrail: [...claim.auditTrail, event],
    );

    return TransitionResult.success(updated);
  }

  // ─── 2. Submit FRC Findings & Customary Boundary ───────────────────────
  TransitionResult submitFrcFindings(
    Claim claim,
    User actor,
    FrcFindings findings,
  ) {
    if (actor.role != UserRole.frc && actor.role != UserRole.admin) {
      return const TransitionResult.failure(
          'Only Forest Rights Committee members can record FRC findings.');
    }
    if (claim.status != ClaimStatus.submittedToFrc &&
        claim.status != ClaimStatus.frcReview) {
      return TransitionResult.failure(
          'Claim is not currently under FRC review (Current: ${claim.status.displayNameEn}).');
    }

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: 'FRC_FINDINGS_SUBMITTED',
      previousState: claim.status.name,
      newState: ClaimStatus.gramSabhaReview.name,
      comment:
          'FRC completed boundary investigation and submitted findings to Gram Sabha.',
    );

    final updated = claim.copyWith(
      status: ClaimStatus.gramSabhaReview,
      assignedAuthority: UserRole.villager, // Village / Gram Sabha review
      frcFindings: findings,
      auditTrail: [...claim.auditTrail, event],
    );

    return TransitionResult.success(updated);
  }

  // ─── 3. Record Gram Sabha Resolution ──────────────────────────────────
  TransitionResult recordGramSabhaResolution(
    Claim claim,
    User actor,
    GramSabhaReviewData reviewData,
  ) {
    if (actor.role != UserRole.villager &&
        actor.role != UserRole.frc &&
        actor.role != UserRole.admin) {
      return const TransitionResult.failure(
          'Only authorized Village Users, FRC, or Admins can record Gram Sabha resolutions.');
    }
    if (claim.status != ClaimStatus.gramSabhaReview) {
      return TransitionResult.failure(
          'Claim is not awaiting Gram Sabha review (Current: ${claim.status.displayNameEn}).');
    }

    final isApproved = reviewData.resolutionResult == 'APPROVED';
    final nextStatus = isApproved
        ? ClaimStatus.gramSabhaApproved
        : ClaimStatus.gramSabhaReturned;
    final nextAuthority = isApproved ? UserRole.forestOfficer : UserRole.frc;

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: isApproved ? 'GRAM_SABHA_APPROVED' : 'GRAM_SABHA_RETURNED',
      previousState: claim.status.name,
      newState: nextStatus.name,
      comment:
          'Gram Sabha Resolution ${reviewData.resolutionNumber}: ${reviewData.resolutionResult}. Notes: ${reviewData.discussionNotes}',
    );

    final updated = claim.copyWith(
      status: nextStatus,
      assignedAuthority: nextAuthority,
      gramSabhaReview: reviewData,
      auditTrail: [...claim.auditTrail, event],
    );

    return TransitionResult.success(updated);
  }

  // ─── 4. Forward to Field Verification ─────────────────────────────────
  TransitionResult forwardToFieldVerification(Claim claim, User actor) {
    if (claim.status != ClaimStatus.gramSabhaApproved) {
      return TransitionResult.failure(
          'Claim must be Gram Sabha Approved before field verification (Current: ${claim.status.displayNameEn}).');
    }

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: 'FIELD_VERIFICATION_STARTED',
      previousState: claim.status.name,
      newState: ClaimStatus.fieldVerificationPending.name,
      comment:
          'Forwarded for joint field verification by Forest and Revenue Officers.',
    );

    final updated = claim.copyWith(
      status: ClaimStatus.fieldVerificationPending,
      assignedAuthority: UserRole.forestOfficer,
      auditTrail: [...claim.auditTrail, event],
    );

    return TransitionResult.success(updated);
  }

  // ─── 5. Submit Field Verification (Forest / Revenue) ───────────────────
  TransitionResult submitFieldVerification(
    Claim claim,
    User actor,
    FieldVerificationRecord record,
  ) {
    if (record.department == 'forest' &&
        actor.role != UserRole.forestOfficer &&
        actor.role != UserRole.admin) {
      return const TransitionResult.failure(
          'Only Forest Department Field Officers can submit forest verification.');
    }
    if (record.department == 'revenue' &&
        actor.role != UserRole.revenueOfficer &&
        actor.role != UserRole.admin) {
      return const TransitionResult.failure(
          'Only Revenue Department Field Officers can submit revenue verification.');
    }

    FieldVerificationRecord? newForest = claim.forestVerification;
    FieldVerificationRecord? newRevenue = claim.revenueVerification;

    if (record.department == 'forest') {
      newForest = record;
    } else {
      newRevenue = record;
    }

    final isBothCompleted = newForest != null &&
        newForest.verificationStatus == 'COMPLETED' &&
        newRevenue != null &&
        newRevenue.verificationStatus == 'COMPLETED';

    final nextStatus = isBothCompleted
        ? ClaimStatus.fieldVerificationCompleted
        : ClaimStatus.fieldVerificationInProgress;

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: '${record.department.toUpperCase()}_VERIFICATION_SUBMITTED',
      previousState: claim.status.name,
      newState: nextStatus.name,
      comment:
          '${record.department.toUpperCase()} field verification submitted by ${record.officerName} (${record.officerDesignation}).',
    );

    Claim updated = claim.copyWith(
      status: nextStatus,
      forestVerification: newForest,
      revenueVerification: newRevenue,
      assignedAuthority:
          isBothCompleted ? UserRole.sdlc : UserRole.revenueOfficer,
      auditTrail: [...claim.auditTrail, event],
    );

    // If both field verifications are completed, automatically transition to SDLC Review
    if (isBothCompleted) {
      final sdlcEvent = _createEvent(
        claimId: claim.id,
        actor: actor,
        action: 'FORWARDED_TO_SDLC',
        previousState: ClaimStatus.fieldVerificationCompleted.name,
        newState: ClaimStatus.sdlcReview.name,
        comment:
          'Joint field verifications completed. Claim forwarded to SDLC.',
      );

      updated = updated.copyWith(
        status: ClaimStatus.sdlcReview,
        assignedAuthority: UserRole.sdlc,
        auditTrail: [...updated.auditTrail, sdlcEvent],
      );
    }

    return TransitionResult.success(updated);
  }

  // ─── 6. SDLC Review & Forward to DLC ──────────────────────────────────
  TransitionResult submitSdlcReview(
    Claim claim,
    User actor,
    SdlcReviewData sdlcData,
  ) {
    if (actor.role != UserRole.sdlc && actor.role != UserRole.admin) {
      return const TransitionResult.failure(
          'Only SDLC members can record SDLC reviews.');
    }
    if (claim.status != ClaimStatus.sdlcReview) {
      return TransitionResult.failure(
          'Claim is not currently under SDLC review (Current: ${claim.status.displayNameEn}).');
    }

    final isApproved = sdlcData.decision == 'APPROVED';
    final nextStatus =
        isApproved ? ClaimStatus.forwardedToDlc : ClaimStatus.sdlcReturned;
    final nextAuthority = isApproved ? UserRole.dlc : UserRole.frc;

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: isApproved ? 'SDLC_APPROVED_FORWARDED' : 'SDLC_RETURNED',
      previousState: claim.status.name,
      newState: nextStatus.name,
      comment:
          'SDLC Review (${sdlcData.decision}). Draft Details: ${sdlcData.draftRecordDetails}',
    );

    final updated = claim.copyWith(
      status: nextStatus,
      assignedAuthority: nextAuthority,
      sdlcReview: sdlcData,
      auditTrail: [...claim.auditTrail, event],
    );

    return TransitionResult.success(updated);
  }

  // ─── 7. Record DLC Decision (Approve / Remand / Modify / Reject) ───────
  TransitionResult recordDlcDecision(
    Claim claim,
    User actor,
    DlcDecisionData dlcData,
  ) {
    if (actor.role != UserRole.dlc && actor.role != UserRole.admin) {
      return const TransitionResult.failure(
          'Only District Level Committee (DLC) members can record DLC decisions.');
    }

    if (dlcData.remarks.trim().isEmpty &&
        dlcData.decisionType != 'dlcApproved') {
      return const TransitionResult.failure(
          'Decision reason/remarks are mandatory for DLC Remand, Modify, or Reject decisions.');
    }

    ClaimStatus nextStatus;
    UserRole nextAuthority;

    switch (dlcData.decisionType) {
      case 'dlcApproved':
        nextStatus = ClaimStatus.dlcApproved;
        nextAuthority = UserRole.dfo; // Next is DFO for Annexure IV
        break;
      case 'dlcRemanded':
        nextStatus = ClaimStatus.dlcRemanded;
        nextAuthority = UserRole.sdlc;
        break;
      case 'dlcModified':
        nextStatus = ClaimStatus.dlcModified;
        nextAuthority = UserRole.dfo;
        break;
      case 'dlcRejected':
        nextStatus = ClaimStatus.dlcRejected;
        nextAuthority = UserRole.villager;
        break;
      default:
        return const TransitionResult.failure('Invalid DLC decision type.');
    }

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: dlcData.decisionType.toUpperCase(),
      previousState: claim.status.name,
      newState: nextStatus.name,
      comment:
          'DLC Order (${dlcData.decisionType}): ${dlcData.remarks}. By: ${dlcData.officerName}',
    );

    Claim updated = claim.copyWith(
      status: nextStatus,
      assignedAuthority: nextAuthority,
      dlcDecision: dlcData,
      auditTrail: [...claim.auditTrail, event],
    );

    // If DLC Approved/Modified, auto-initiate Annexure IV workflow
    if (nextStatus == ClaimStatus.dlcApproved ||
        nextStatus == ClaimStatus.dlcModified) {
      final titleNo = 'ANNEX-IV-${claim.id.replaceAll('CFR-', '')}';
      final annexIV = AnnexureIVData(
        titleNumber: titleNo,
        issuedDate: DateTime.now(),
        signatures: const [],
      );

      final annexEvent = _createEvent(
        claimId: claim.id,
        actor: actor,
        action: 'ANNEXURE_IV_INITIATED',
        previousState: nextStatus.name,
        newState: ClaimStatus.annexureIvPendingDfo.name,
        comment:
            'Annexure IV Title $titleNo generated. Pending DFO signature.',
      );

      updated = updated.copyWith(
        status: ClaimStatus.annexureIvPendingDfo,
        assignedAuthority: UserRole.dfo,
        annexureIV: annexIV,
        auditTrail: [...updated.auditTrail, annexEvent],
      );
    }

    return TransitionResult.success(updated);
  }

  // ─── 8. Sign Annexure IV (DFO → DTWO → Collector) ─────────────────────
  Future<TransitionResult> signAnnexureIV(
    Claim claim,
    User actor, {
    required String notes,
  }) async {
    final annex = claim.annexureIV;
    if (annex == null) {
      return const TransitionResult.failure(
          'Annexure IV record has not been generated for this claim.');
    }

    // Role validation & state check
    if (claim.status == ClaimStatus.annexureIvPendingDfo) {
      if (actor.role != UserRole.dfo && actor.role != UserRole.admin) {
        return const TransitionResult.failure(
            'Only Divisional Forest Officer (DFO/DCF) can sign as Forest Authority.');
      }
    } else if (claim.status == ClaimStatus.annexureIvPendingTribalWelfare) {
      if (actor.role != UserRole.dtwo && actor.role != UserRole.admin) {
        return const TransitionResult.failure(
            'Only District Tribal Welfare Officer can sign as Tribal Welfare Authority.');
      }
    } else if (claim.status == ClaimStatus.annexureIvPendingCollector) {
      if (actor.role != UserRole.collector && actor.role != UserRole.admin) {
        return const TransitionResult.failure(
            'Only District Collector / Deputy Commissioner can give final Annexure IV signature.');
      }
    } else {
      return TransitionResult.failure(
          'Claim is not currently awaiting Annexure IV signature (Current: ${claim.status.displayNameEn}).');
    }

    final signedAt = DateTime.now();
    final sigHash = await _signatureService.generateSignatureHash(
      claimId: claim.id,
      signerId: actor.id,
      signerRole: actor.role,
      timestamp: signedAt,
    );

    final signature = AnnexureIVSignature(
      role: actor.role.name,
      signerName: actor.name,
      designation: actor.role.displayNameEn,
      signedAt: signedAt,
      signatureHash: sigHash,
      notes: notes,
    );

    final updatedSignatures = [...annex.signatures, signature];
    final updatedAnnex = AnnexureIVData(
      titleNumber: annex.titleNumber,
      issuedDate: annex.issuedDate,
      signatures: updatedSignatures,
    );

    ClaimStatus nextStatus;
    UserRole nextAuthority;

    if (actor.role == UserRole.dfo ||
        claim.status == ClaimStatus.annexureIvPendingDfo) {
      nextStatus = ClaimStatus.annexureIvPendingTribalWelfare;
      nextAuthority = UserRole.dtwo;
    } else if (actor.role == UserRole.dtwo ||
        claim.status == ClaimStatus.annexureIvPendingTribalWelfare) {
      nextStatus = ClaimStatus.annexureIvPendingCollector;
      nextAuthority = UserRole.collector;
    } else {
      nextStatus = ClaimStatus.annexureIvCompleted;
      nextAuthority = UserRole.recordOfficer;
    }

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: 'ANNEXURE_IV_SIGNED_${actor.role.name.toUpperCase()}',
      previousState: claim.status.name,
      newState: nextStatus.name,
      comment:
          'Annexure IV Title ${annex.titleNumber} signed by ${actor.name} (${actor.role.displayNameEn}). Hash: $sigHash',
    );

    Claim updated = claim.copyWith(
      status: nextStatus,
      assignedAuthority: nextAuthority,
      annexureIV: updatedAnnex,
      auditTrail: [...claim.auditTrail, event],
    );

    // If all three signatures complete, transition to Record Incorporation Pending
    if (updatedAnnex.isFullySigned || nextStatus == ClaimStatus.annexureIvCompleted) {
      final recEvent = _createEvent(
        claimId: claim.id,
        actor: actor,
        action: 'FORWARDED_TO_RECORD_INCORPORATION',
        previousState: ClaimStatus.annexureIvCompleted.name,
        newState: ClaimStatus.recordIncorporationPending.name,
        comment:
            'All Annexure IV signatures complete. Title forwarded for official land record incorporation.',
      );

      updated = updated.copyWith(
        status: ClaimStatus.recordIncorporationPending,
        assignedAuthority: UserRole.recordOfficer,
        auditTrail: [...updated.auditTrail, recEvent],
      );
    }

    return TransitionResult.success(updated);
  }

  // ─── 9. Complete Record Incorporation ─────────────────────────────────
  TransitionResult completeRecordIncorporation(
    Claim claim,
    User actor,
    RecordIncorporationData incorporationData,
  ) {
    if (actor.role != UserRole.recordOfficer && actor.role != UserRole.admin) {
      return const TransitionResult.failure(
          'Only Record Incorporation Officers can record official land record incorporation.');
    }
    if (claim.status != ClaimStatus.recordIncorporationPending) {
      return TransitionResult.failure(
          'Claim is not awaiting record incorporation (Current: ${claim.status.displayNameEn}).');
    }

    final event = _createEvent(
      claimId: claim.id,
      actor: actor,
      action: 'RECORD_INCORPORATED',
      previousState: claim.status.name,
      newState: ClaimStatus.completed.name,
      comment:
          'Title incorporated into Revenue Record #${incorporationData.revenueRecordNumber} & Forest Record #${incorporationData.forestRecordNumber}. Workflow Completed.',
    );

    final updated = claim.copyWith(
      status: ClaimStatus.completed,
      assignedAuthority: UserRole.slmc, // State Monitoring Oversight
      recordIncorporation: incorporationData,
      auditTrail: [...claim.auditTrail, event],
    );

    return TransitionResult.success(updated);
  }

  // Helper to generate immutable audit log events
  WorkflowEvent _createEvent({
    required String claimId,
    required User actor,
    required String action,
    required String previousState,
    required String newState,
    required String comment,
    String? documentRef,
  }) {
    return WorkflowEvent(
      id: const Uuid().v4(),
      claimId: claimId,
      actorId: actor.id,
      actorRole: actor.role,
      action: action,
      timestamp: DateTime.now(),
      previousState: previousState,
      newState: newState,
      comment: comment,
      documentRef: documentRef,
    );
  }
}
