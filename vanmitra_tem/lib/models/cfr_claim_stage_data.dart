import 'user_role.dart';

/// FRC (Forest Rights Committee) Investigation Findings
class FrcFindings {
  final String customaryBoundaryDescription;
  final List<String> borderingVillages;
  final List<String> gramSabhaMembersPresent;
  final List<String> frcMembersPresent;
  final List<String> eldersInvolvedInDelineation;
  final String acknowledgmentNumber;
  final DateTime acknowledgmentDate;
  final String frcRemarks;
  final DateTime submittedAt;

  const FrcFindings({
    this.customaryBoundaryDescription = '',
    this.borderingVillages = const [],
    this.gramSabhaMembersPresent = const [],
    this.frcMembersPresent = const [],
    this.eldersInvolvedInDelineation = const [],
    this.acknowledgmentNumber = '',
    required this.submittedAt,
    this.frcRemarks = '',

    DateTime? acknowledgmentDate,
  }) : acknowledgmentDate = acknowledgmentDate ?? submittedAt;

  Map<String, dynamic> toJson() => {
        'customaryBoundaryDescription': customaryBoundaryDescription,
        'borderingVillages': borderingVillages,
        'gramSabhaMembersPresent': gramSabhaMembersPresent,
        'frcMembersPresent': frcMembersPresent,
        'eldersInvolvedInDelineation': eldersInvolvedInDelineation,
        'acknowledgmentNumber': acknowledgmentNumber,
        'acknowledgmentDate': acknowledgmentDate.toIso8601String(),
        'frcRemarks': frcRemarks,
        'submittedAt': submittedAt.toIso8601String(),
      };

  factory FrcFindings.fromJson(Map<String, dynamic> json) => FrcFindings(
        customaryBoundaryDescription:
            json['customaryBoundaryDescription'] as String? ?? '',
        borderingVillages: (json['borderingVillages'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
        gramSabhaMembersPresent: (json['gramSabhaMembersPresent'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
        frcMembersPresent:
            (json['frcMembersPresent'] as List<dynamic>?)?.cast<String>() ??
                const [],
        eldersInvolvedInDelineation:
            (json['eldersInvolvedInDelineation'] as List<dynamic>?)
                    ?.cast<String>() ??
                const [],
        acknowledgmentNumber: json['acknowledgmentNumber'] as String? ?? '',
        acknowledgmentDate: json['acknowledgmentDate'] != null
            ? DateTime.parse(json['acknowledgmentDate'] as String)
            : DateTime.now(),
        frcRemarks: json['frcRemarks'] as String? ?? '',
        submittedAt: json['submittedAt'] != null
            ? DateTime.parse(json['submittedAt'] as String)
            : DateTime.now(),
      );
}

/// Gram Sabha Resolution & Review Record
class GramSabhaReviewData {
  final DateTime meetingDate;
  final String meetingLocation;
  final int totalAttendees;
  final int registeredVoters;
  final int womenAttendees;
  final bool quorumAchieved;
  final String discussionNotes;
  final String resolutionNumber;
  final String resolutionResult; // 'APPROVED', 'RETURNED_FOR_CORRECTION'
  final DateTime recordedAt;

  const GramSabhaReviewData({
    required this.meetingDate,
    required this.meetingLocation,
    this.totalAttendees = 0,
    this.registeredVoters = 0,
    this.womenAttendees = 0,
    this.quorumAchieved = true,
    this.discussionNotes = '',
    required this.resolutionNumber,
    required this.resolutionResult,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'meetingDate': meetingDate.toIso8601String(),
        'meetingLocation': meetingLocation,
        'totalAttendees': totalAttendees,
        'registeredVoters': registeredVoters,
        'womenAttendees': womenAttendees,
        'quorumAchieved': quorumAchieved,
        'discussionNotes': discussionNotes,
        'resolutionNumber': resolutionNumber,
        'resolutionResult': resolutionResult,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory GramSabhaReviewData.fromJson(Map<String, dynamic> json) =>
      GramSabhaReviewData(
        meetingDate: DateTime.parse(json['meetingDate'] as String),
        meetingLocation: json['meetingLocation'] as String? ?? '',
        totalAttendees: json['totalAttendees'] as int? ?? 0,
        registeredVoters: json['registeredVoters'] as int? ?? 0,
        womenAttendees: json['womenAttendees'] as int? ?? 0,
        quorumAchieved: json['quorumAchieved'] as bool? ?? true,
        discussionNotes: json['discussionNotes'] as String? ?? '',
        resolutionNumber: json['resolutionNumber'] as String? ?? '',
        resolutionResult: json['resolutionResult'] as String? ?? 'APPROVED',
        recordedAt: DateTime.parse(json['recordedAt'] as String),
      );
}

/// Independent Field Verification Record (Forest or Revenue Department)
class FieldVerificationRecord {
  final String department; // 'forest' or 'revenue'
  final String officerId;
  final String officerName;
  final String officerDesignation;
  final DateTime visitDate;
  final String observations;
  final double? verifiedAreaSqMeters;
  final String verificationStatus; // 'COMPLETED', 'PENDING', 'ABSENT', 'REQUIRES_REVIEW'
  final String signatureHash;
  final DateTime submittedAt;

  const FieldVerificationRecord({
    required this.department,
    required this.officerId,
    required this.officerName,
    required this.officerDesignation,
    required this.visitDate,
    required this.observations,
    this.verifiedAreaSqMeters,
    required this.verificationStatus,
    this.signatureHash = '',
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() => {
        'department': department,
        'officerId': officerId,
        'officerName': officerName,
        'officerDesignation': officerDesignation,
        'visitDate': visitDate.toIso8601String(),
        'observations': observations,
        'verifiedAreaSqMeters': verifiedAreaSqMeters,
        'verificationStatus': verificationStatus,
        'signatureHash': signatureHash,
        'submittedAt': submittedAt.toIso8601String(),
      };

  factory FieldVerificationRecord.fromJson(Map<String, dynamic> json) =>
      FieldVerificationRecord(
        department: json['department'] as String,
        officerId: json['officerId'] as String? ?? '',
        officerName: json['officerName'] as String? ?? '',
        officerDesignation: json['officerDesignation'] as String? ?? '',
        visitDate: DateTime.parse(json['visitDate'] as String),
        observations: json['observations'] as String? ?? '',
        verifiedAreaSqMeters:
            (json['verifiedAreaSqMeters'] as num?)?.toDouble(),
        verificationStatus:
            json['verificationStatus'] as String? ?? 'COMPLETED',
        signatureHash: json['signatureHash'] as String? ?? '',
        submittedAt: DateTime.parse(json['submittedAt'] as String),
      );
}

/// SDLC Review Data
class SdlcReviewData {
  final DateTime reviewDate;
  final String officerName;
  final String consolidatedMapRef;
  final String observations;
  final String draftRecordDetails;
  final String decision; // 'APPROVED', 'RETURNED'
  final DateTime submittedAt;

  const SdlcReviewData({
    required this.reviewDate,
    required this.officerName,
    this.consolidatedMapRef = '',
    required this.observations,
    required this.draftRecordDetails,
    required this.decision,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() => {
        'reviewDate': reviewDate.toIso8601String(),
        'officerName': officerName,
        'consolidatedMapRef': consolidatedMapRef,
        'observations': observations,
        'draftRecordDetails': draftRecordDetails,
        'decision': decision,
        'submittedAt': submittedAt.toIso8601String(),
      };

  factory SdlcReviewData.fromJson(Map<String, dynamic> json) => SdlcReviewData(
        reviewDate: DateTime.parse(json['reviewDate'] as String),
        officerName: json['officerName'] as String? ?? '',
        consolidatedMapRef: json['consolidatedMapRef'] as String? ?? '',
        observations: json['observations'] as String? ?? '',
        draftRecordDetails: json['draftRecordDetails'] as String? ?? '',
        decision: json['decision'] as String? ?? 'APPROVED',
        submittedAt: DateTime.parse(json['submittedAt'] as String),
      );
}

/// DLC Final Order & Decision Record
class DlcDecisionData {
  final String decisionType; // 'dlcApproved', 'dlcRemanded', 'dlcModified', 'dlcRejected'
  final DateTime decisionDate;
  final String remarks;
  final String modifiedDetails;
  final String officerName;

  const DlcDecisionData({
    required this.decisionType,
    required this.decisionDate,
    required this.remarks,
    this.modifiedDetails = '',
    required this.officerName,
  });

  Map<String, dynamic> toJson() => {
        'decisionType': decisionType,
        'decisionDate': decisionDate.toIso8601String(),
        'remarks': remarks,
        'modifiedDetails': modifiedDetails,
        'officerName': officerName,
      };

  factory DlcDecisionData.fromJson(Map<String, dynamic> json) =>
      DlcDecisionData(
        decisionType: json['decisionType'] as String,
        decisionDate: DateTime.parse(json['decisionDate'] as String),
        remarks: json['remarks'] as String? ?? '',
        modifiedDetails: json['modifiedDetails'] as String? ?? '',
        officerName: json['officerName'] as String? ?? '',
      );
}

/// Annexure IV Title Signatory Record
class AnnexureIVSignature {
  final String role; // 'dfo', 'dtwo', 'collector'
  final String signerName;
  final String designation;
  final DateTime signedAt;
  final String signatureHash;
  final String notes;

  const AnnexureIVSignature({
    required this.role,
    required this.signerName,
    required this.designation,
    required this.signedAt,
    required this.signatureHash,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'signerName': signerName,
        'designation': designation,
        'signedAt': signedAt.toIso8601String(),
        'signatureHash': signatureHash,
        'notes': notes,
      };

  factory AnnexureIVSignature.fromJson(Map<String, dynamic> json) =>
      AnnexureIVSignature(
        role: json['role'] as String,
        signerName: json['signerName'] as String? ?? '',
        designation: json['designation'] as String? ?? '',
        signedAt: DateTime.parse(json['signedAt'] as String),
        signatureHash: json['signatureHash'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

/// Annexure IV Complete Title Data
class AnnexureIVData {
  final String titleNumber;
  final DateTime issuedDate;
  final List<AnnexureIVSignature> signatures;

  const AnnexureIVData({
    required this.titleNumber,
    required this.issuedDate,
    this.signatures = const [],
  });

  bool get isDfoSigned => signatures.any((s) => s.role == 'dfo');
  bool get isDtwoSigned => signatures.any((s) => s.role == 'dtwo');
  bool get isCollectorSigned => signatures.any((s) => s.role == 'collector');
  bool get isFullySigned => isDfoSigned && isDtwoSigned && isCollectorSigned;

  Map<String, dynamic> toJson() => {
        'titleNumber': titleNumber,
        'issuedDate': issuedDate.toIso8601String(),
        'signatures': signatures.map((s) => s.toJson()).toList(),
      };

  factory AnnexureIVData.fromJson(Map<String, dynamic> json) => AnnexureIVData(
        titleNumber: json['titleNumber'] as String? ?? '',
        issuedDate: DateTime.parse(json['issuedDate'] as String),
        signatures: (json['signatures'] as List<dynamic>?)
                ?.map((s) =>
                    AnnexureIVSignature.fromJson(s as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Record Incorporation Data
class RecordIncorporationData {
  final String revenueRecordNumber;
  final String forestRecordNumber;
  final DateTime incorporationDate;
  final String recordOfficerName;
  final String remarks;
  final String finalMapReference;

  const RecordIncorporationData({
    required this.revenueRecordNumber,
    required this.forestRecordNumber,
    required this.incorporationDate,
    required this.recordOfficerName,
    this.remarks = '',
    this.finalMapReference = '',
  });

  Map<String, dynamic> toJson() => {
        'revenueRecordNumber': revenueRecordNumber,
        'forestRecordNumber': forestRecordNumber,
        'incorporationDate': incorporationDate.toIso8601String(),
        'recordOfficerName': recordOfficerName,
        'remarks': remarks,
        'finalMapReference': finalMapReference,
      };

  factory RecordIncorporationData.fromJson(Map<String, dynamic> json) =>
      RecordIncorporationData(
        revenueRecordNumber: json['revenueRecordNumber'] as String? ?? '',
        forestRecordNumber: json['forestRecordNumber'] as String? ?? '',
        incorporationDate:
            DateTime.parse(json['incorporationDate'] as String),
        recordOfficerName: json['recordOfficerName'] as String? ?? '',
        remarks: json['remarks'] as String? ?? '',
        finalMapReference: json['finalMapReference'] as String? ?? '',
      );
}

/// Immutable Audit Trail Event Record
class WorkflowEvent {
  final String id;
  final String claimId;
  final String actorId;
  final UserRole actorRole;
  final String action;
  final DateTime timestamp;
  final String previousState;
  final String newState;
  final String comment;
  final String? documentRef;

  const WorkflowEvent({
    required this.id,
    required this.claimId,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.timestamp,
    required this.previousState,
    required this.newState,
    required this.comment,
    this.documentRef,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'claimId': claimId,
        'actorId': actorId,
        'actorRole': actorRole.name,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'previousState': previousState,
        'newState': newState,
        'comment': comment,
        'documentRef': documentRef,
      };

  factory WorkflowEvent.fromJson(Map<String, dynamic> json) => WorkflowEvent(
        id: json['id'] as String,
        claimId: json['claimId'] as String,
        actorId: json['actorId'] as String? ?? '',
        actorRole: UserRoleExtension.parse(json['actorRole'] as String?),
        action: json['action'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        previousState: json['previousState'] as String? ?? '',
        newState: json['newState'] as String? ?? '',
        comment: json['comment'] as String? ?? '',
        documentRef: json['documentRef'] as String?,
      );
}
