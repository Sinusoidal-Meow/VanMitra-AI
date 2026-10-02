import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import 'cfr_claim_stage_data.dart';
import 'user_role.dart';

/// FRA & CFR claim types
enum ClaimType {
  /// Form A — Individual Forest Right (IFR) under Sec. 3(1)(a)
  /// or Community Rights (CR) under Sec. 3(1)(b-d)
  formA,

  /// Form B — Community Forest Resource Right (CFRR) under Sec. 3(1)(i)
  formB,
}

/// Centralized CFR & FRA Workflow State Machine Statuses
enum ClaimStatus {
  draft,
  submittedToFrc,
  frcReview,
  gramSabhaReview,
  gramSabhaReturned,
  gramSabhaApproved,
  fieldVerificationPending,
  fieldVerificationInProgress,
  fieldVerificationCompleted,
  sdlcReview,
  sdlcReturned,
  sdlcApproved,
  forwardedToDlc,
  dlcReview,
  dlcRemanded,
  dlcModified,
  dlcRejected,
  dlcApproved,
  annexureIvPendingDfo,
  annexureIvPendingTribalWelfare,
  annexureIvPendingCollector,
  annexureIvCompleted,
  recordIncorporationPending,
  recordIncorporated,
  completed,

  // Legacy fallback aliases kept for database safety
  submitted,
  underReview,
  approved,
  rejected,
  appealFiled,
}

extension ClaimStatusExtension on ClaimStatus {
  bool get isApproved {
    switch (this) {
      case ClaimStatus.dlcApproved:
      case ClaimStatus.annexureIvPendingDfo:
      case ClaimStatus.annexureIvPendingTribalWelfare:
      case ClaimStatus.annexureIvPendingCollector:
      case ClaimStatus.annexureIvCompleted:
      case ClaimStatus.recordIncorporationPending:
      case ClaimStatus.recordIncorporated:
      case ClaimStatus.completed:
      case ClaimStatus.approved:
        return true;
      default:
        return false;
    }
  }

  bool get isRejected {
    switch (this) {
      case ClaimStatus.dlcRejected:
      case ClaimStatus.dlcRemanded:
      case ClaimStatus.gramSabhaReturned:
      case ClaimStatus.sdlcReturned:
      case ClaimStatus.rejected:
        return true;
      default:
        return false;
    }
  }

  bool get isPending => !isApproved && !isRejected;

  String getLocalizedStatus(BuildContext context) {
    try {
      switch (this) {
        case ClaimStatus.draft:
          return context.tr('claim_status_draft');
        case ClaimStatus.submittedToFrc:
        case ClaimStatus.submitted:
          return context.tr('claim_status_submitted');
        case ClaimStatus.frcReview:
        case ClaimStatus.gramSabhaReview:
        case ClaimStatus.underReview:
          return context.tr('claim_status_under_review');
        case ClaimStatus.completed:
        case ClaimStatus.approved:
        case ClaimStatus.dlcApproved:
        case ClaimStatus.recordIncorporated:
          return context.tr('claim_status_approved');
        case ClaimStatus.rejected:
        case ClaimStatus.dlcRejected:
          return context.tr('claim_status_rejected');
        case ClaimStatus.appealFiled:
          return context.tr('claim_status_appeal');
        default:
          return displayNameEn;
      }
    } catch (_) {
      return displayNameEn;
    }
  }

  String get displayNameEn {
    switch (this) {
      case ClaimStatus.draft:
        return 'Draft';
      case ClaimStatus.submittedToFrc:
        return 'Submitted to FRC';
      case ClaimStatus.frcReview:
        return 'FRC Review';
      case ClaimStatus.gramSabhaReview:
        return 'Gram Sabha Review';
      case ClaimStatus.gramSabhaReturned:
        return 'Gram Sabha Returned';
      case ClaimStatus.gramSabhaApproved:
        return 'Gram Sabha Approved';
      case ClaimStatus.fieldVerificationPending:
        return 'Field Verification Pending';
      case ClaimStatus.fieldVerificationInProgress:
        return 'Field Verification In Progress';
      case ClaimStatus.fieldVerificationCompleted:
        return 'Field Verification Completed';
      case ClaimStatus.sdlcReview:
        return 'SDLC Review';
      case ClaimStatus.sdlcReturned:
        return 'SDLC Returned';
      case ClaimStatus.sdlcApproved:
        return 'SDLC Approved';
      case ClaimStatus.forwardedToDlc:
        return 'Forwarded to DLC';
      case ClaimStatus.dlcReview:
        return 'DLC Review';
      case ClaimStatus.dlcRemanded:
        return 'DLC Remanded';
      case ClaimStatus.dlcModified:
        return 'DLC Modified';
      case ClaimStatus.dlcRejected:
        return 'DLC Rejected';
      case ClaimStatus.dlcApproved:
        return 'DLC Approved';
      case ClaimStatus.annexureIvPendingDfo:
        return 'Annexure IV Pending DFO';
      case ClaimStatus.annexureIvPendingTribalWelfare:
        return 'Annexure IV Pending Tribal Welfare';
      case ClaimStatus.annexureIvPendingCollector:
        return 'Annexure IV Pending Collector';
      case ClaimStatus.annexureIvCompleted:
        return 'Annexure IV Completed';
      case ClaimStatus.recordIncorporationPending:
        return 'Record Incorporation Pending';
      case ClaimStatus.recordIncorporated:
        return 'Record Incorporated';
      case ClaimStatus.completed:
        return 'Completed';

      case ClaimStatus.submitted:
        return 'Submitted';
      case ClaimStatus.underReview:
        return 'Under Review';
      case ClaimStatus.approved:
        return 'Approved';
      case ClaimStatus.rejected:
        return 'Rejected';
      case ClaimStatus.appealFiled:
        return 'Appeal Filed';
    }
  }

  String get displayNameMr {
    switch (this) {
      case ClaimStatus.draft:
        return 'मसुदा';
      case ClaimStatus.submittedToFrc:
        return 'FRC कडे सादर';
      case ClaimStatus.frcReview:
        return 'FRC पुनरावलोकन';
      case ClaimStatus.gramSabhaReview:
        return 'ग्रामसभा पुनरावलोकन';
      case ClaimStatus.gramSabhaReturned:
        return 'ग्रामसभेने परत पाठवले';
      case ClaimStatus.gramSabhaApproved:
        return 'ग्रामसभा मंजूर';
      case ClaimStatus.fieldVerificationPending:
        return 'क्षेत्र पडताळणी प्रलंबित';
      case ClaimStatus.fieldVerificationInProgress:
        return 'क्षेत्र पडताळणी सुरू';
      case ClaimStatus.fieldVerificationCompleted:
        return 'क्षेत्र पडताळणी पूर्ण';
      case ClaimStatus.sdlcReview:
        return 'SDLC पुनरावलोकन';
      case ClaimStatus.sdlcReturned:
        return 'SDLC परत पाठवले';
      case ClaimStatus.sdlcApproved:
        return 'SDLC मंजूर';
      case ClaimStatus.forwardedToDlc:
        return 'DLC कडे पाठवले';
      case ClaimStatus.dlcReview:
        return 'DLC पुनरावलोकन';
      case ClaimStatus.dlcRemanded:
        return 'DLC कडे फेरविचारार्थ';
      case ClaimStatus.dlcModified:
        return 'DLC सुधारित';
      case ClaimStatus.dlcRejected:
        return 'DLC नामंजूर';
      case ClaimStatus.dlcApproved:
        return 'DLC मंजूर';
      case ClaimStatus.annexureIvPendingDfo:
        return 'परिशिष्ट IV DFO स्वाक्षरी प्रलंबित';
      case ClaimStatus.annexureIvPendingTribalWelfare:
        return 'परिशिष्ट IV आदिवासी कल्याण स्वाक्षरी प्रलंबित';
      case ClaimStatus.annexureIvPendingCollector:
        return 'परिशिष्ट IV जिल्हाधिकारी स्वाक्षरी प्रलंबित';
      case ClaimStatus.annexureIvCompleted:
        return 'परिशिष्ट IV पूर्ण';
      case ClaimStatus.recordIncorporationPending:
        return 'अभिलेख नोंदणी प्रलंबित';
      case ClaimStatus.recordIncorporated:
        return 'अभिलेख नोंदणी पूर्ण';
      case ClaimStatus.completed:
        return 'पूर्ण';

      case ClaimStatus.submitted:
        return 'सादर';
      case ClaimStatus.underReview:
        return 'पुनरावलोकन';
      case ClaimStatus.approved:
        return 'मंजूर';
      case ClaimStatus.rejected:
        return 'नामंजूर';
      case ClaimStatus.appealFiled:
        return 'अपील दाखल';
    }
  }

  String get icon {
    if (isApproved) return '✅';
    if (isRejected) return '❌';
    switch (this) {
      case ClaimStatus.draft:
        return '📝';
      case ClaimStatus.submittedToFrc:
        return '📤';
      case ClaimStatus.frcReview:
        return '🔎';
      case ClaimStatus.gramSabhaReview:
        return '👥';
      case ClaimStatus.fieldVerificationPending:
      case ClaimStatus.fieldVerificationInProgress:
        return '📍';
      case ClaimStatus.sdlcReview:
      case ClaimStatus.dlcReview:
        return '⚖️';
      case ClaimStatus.annexureIvPendingDfo:
      case ClaimStatus.annexureIvPendingTribalWelfare:
      case ClaimStatus.annexureIvPendingCollector:
        return '✍️';
      case ClaimStatus.recordIncorporationPending:
      case ClaimStatus.recordIncorporated:
        return '📜';
      default:
        return '⏳';
    }
  }

  static ClaimStatus parse(String? value) {
    if (value == null || value.isEmpty) return ClaimStatus.draft;
    try {
      return ClaimStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == value.toLowerCase(),
        orElse: () => ClaimStatus.draft,
      );
    } catch (_) {
      return ClaimStatus.draft;
    }
  }
}

/// Nature of the claimed right
enum ClaimNature {
  cultivation,
  habitation,
  mfpCollection,
  grazing,
  waterBodies,
  traditionalResource,
  other,
}

extension ClaimNatureExtension on ClaimNature {
  String get displayNameEn {
    switch (this) {
      case ClaimNature.cultivation:
        return 'Cultivation';
      case ClaimNature.habitation:
        return 'Habitation';
      case ClaimNature.mfpCollection:
        return 'MFP Collection';
      case ClaimNature.grazing:
        return 'Grazing';
      case ClaimNature.waterBodies:
        return 'Water Bodies';
      case ClaimNature.traditionalResource:
        return 'Traditional Resource';
      case ClaimNature.other:
        return 'Other';
    }
  }

  String get displayNameMr {
    switch (this) {
      case ClaimNature.cultivation:
        return 'शेती';
      case ClaimNature.habitation:
        return 'निवास';
      case ClaimNature.mfpCollection:
        return 'गौण वनोपज संकलन';
      case ClaimNature.grazing:
        return 'चराई';
      case ClaimNature.waterBodies:
        return 'जलस्रोत';
      case ClaimNature.traditionalResource:
        return 'पारंपरिक संसाधन';
      case ClaimNature.other:
        return 'इतर';
    }
  }

  static ClaimNature parse(String? value) {
    if (value == null || value.isEmpty) return ClaimNature.cultivation;
    try {
      return ClaimNature.values.firstWhere(
        (n) => n.name.toLowerCase() == value.toLowerCase(),
        orElse: () => ClaimNature.cultivation,
      );
    } catch (_) {
      return ClaimNature.cultivation;
    }
  }
}

/// Reusable Evidence Item Document Model
class ClaimEvidenceItem {
  final String id;
  final String categoryKey;
  final String title;
  final String description;
  final String fileUrl;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String verificationStatus; // 'PENDING', 'VERIFIED', 'REJECTED'
  final String remarks;
  final String ocrExtractedText;

  const ClaimEvidenceItem({
    required this.id,
    required this.categoryKey,
    required this.title,
    this.description = '',
    required this.fileUrl,
    required this.uploadedAt,
    required this.uploadedBy,
    this.verificationStatus = 'PENDING',
    this.remarks = '',
    this.ocrExtractedText = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryKey': categoryKey,
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'uploadedAt': uploadedAt.toIso8601String(),
        'uploadedBy': uploadedBy,
        'verificationStatus': verificationStatus,
        'remarks': remarks,
        'ocrExtractedText': ocrExtractedText,
      };

  factory ClaimEvidenceItem.fromJson(Map<String, dynamic> json) =>
      ClaimEvidenceItem(
        id: json['id'] as String,
        categoryKey: json['categoryKey'] as String? ?? 'government_records',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        fileUrl: json['fileUrl'] as String? ?? '',
        uploadedAt: json['uploadedAt'] != null
            ? DateTime.parse(json['uploadedAt'] as String)
            : DateTime.now(),
        uploadedBy: json['uploadedBy'] as String? ?? '',
        verificationStatus: json['verificationStatus'] as String? ?? 'PENDING',
        remarks: json['remarks'] as String? ?? '',
        ocrExtractedText: json['ocrExtractedText'] as String? ?? '',
      );
}

/// Complete Community Forest Resource (CFR) & FRA Claim Model
class Claim {
  final String id; // e.g. CFR-MH-PALGHAR-2026-0001
  final String claimantUserId;
  final String villageId;
  final String villageName;
  final String gramPanchayat;
  final String tehsil;
  final String district;
  final String state;
  final ClaimType type;
  final ClaimStatus status;
  final ClaimNature nature;
  final UserRole assignedAuthority;

  // Claimant / Community details
  final String claimantName;
  final String claimantNameEn;
  final String? fatherHusbandName;
  final String? address;
  final String? contactPhone;
  final String? claimDescription;

  // Land / Boundary details
  final String? surveyNumber;
  final double? areaSqMeters;
  final String? landDescription;
  final Map<String, dynamic>? cfrBoundaryGeoJson;

  // Occupation details
  final int? occupationYears;
  final bool occupationBefore2005; // Before 13.12.2005

  // Evidence
  final Map<String, bool> evidenceFlags; // category -> present/absent
  final double evidenceScore; // E ∈ [0, 1]
  final List<String> missingEvidence;
  final List<ClaimEvidenceItem> evidenceList;

  // Stage-specific legal metadata records
  final FrcFindings? frcFindings;
  final GramSabhaReviewData? gramSabhaReview;
  final FieldVerificationRecord? forestVerification;
  final FieldVerificationRecord? revenueVerification;
  final SdlcReviewData? sdlcReview;
  final DlcDecisionData? dlcDecision;
  final AnnexureIVData? annexureIV;
  final RecordIncorporationData? recordIncorporation;

  // Audit trail history
  final List<WorkflowEvent> auditTrail;

  // Dates & Sync
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final DateTime? appealDeadline;
  final bool isSynced;

  const Claim({
    required this.id,
    required this.claimantUserId,
    required this.villageId,
    this.villageName = 'ओझर (Ozhar)',
    this.gramPanchayat = 'ओझर (Ozhar)',
    this.tehsil = 'जव्हार (Jawhar)',
    this.district = 'पालघर (Palghar)',
    this.state = 'महाराष्ट्र (Maharashtra)',
    required this.type,
    required this.status,
    required this.nature,
    this.assignedAuthority = UserRole.villager,
    required this.claimantName,
    required this.claimantNameEn,
    this.fatherHusbandName,
    this.address,
    this.contactPhone,
    this.claimDescription,
    this.surveyNumber,
    this.areaSqMeters,
    this.landDescription,
    this.cfrBoundaryGeoJson,
    this.occupationYears,
    this.occupationBefore2005 = true,
    this.evidenceFlags = const {},
    this.evidenceScore = 0.0,
    this.missingEvidence = const [],
    this.evidenceList = const [],
    this.frcFindings,
    this.gramSabhaReview,
    this.forestVerification,
    this.revenueVerification,
    this.sdlcReview,
    this.dlcDecision,
    this.annexureIV,
    this.recordIncorporation,
    this.auditTrail = const [],
    required this.createdAt,
    this.lastUpdatedAt,
    this.submittedAt,
    this.reviewedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.appealDeadline,
    this.isSynced = false,
  });

  bool get isAppealWindowOpen {
    if (appealDeadline == null) return false;
    return DateTime.now().isBefore(appealDeadline!);
  }

  int get appealDaysRemaining {
    if (appealDeadline == null) return 0;
    final diff = appealDeadline!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  String get evidenceTier {
    if (evidenceScore >= 0.8) return 'green';
    if (evidenceScore >= 0.6) return 'yellow';
    return 'red';
  }

  Claim copyWith({
    ClaimStatus? status,
    UserRole? assignedAuthority,
    Map<String, bool>? evidenceFlags,
    double? evidenceScore,
    List<String>? missingEvidence,
    List<ClaimEvidenceItem>? evidenceList,
    FrcFindings? frcFindings,
    GramSabhaReviewData? gramSabhaReview,
    FieldVerificationRecord? forestVerification,
    FieldVerificationRecord? revenueVerification,
    SdlcReviewData? sdlcReview,
    DlcDecisionData? dlcDecision,
    AnnexureIVData? annexureIV,
    RecordIncorporationData? recordIncorporation,
    List<WorkflowEvent>? auditTrail,
    DateTime? lastUpdatedAt,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    DateTime? rejectedAt,
    String? rejectionReason,
    DateTime? appealDeadline,
    bool? isSynced,
    String? claimantName,
    String? claimantNameEn,
    String? fatherHusbandName,
    String? address,
    String? contactPhone,
    String? claimDescription,
    String? surveyNumber,
    double? areaSqMeters,
    String? landDescription,
    Map<String, dynamic>? cfrBoundaryGeoJson,
    int? occupationYears,
    bool? occupationBefore2005,
    ClaimNature? nature,
  }) {
    return Claim(
      id: id,
      claimantUserId: claimantUserId,
      villageId: villageId,
      villageName: villageName,
      gramPanchayat: gramPanchayat,
      tehsil: tehsil,
      district: district,
      state: state,
      type: type,
      status: status ?? this.status,
      nature: nature ?? this.nature,
      assignedAuthority: assignedAuthority ?? this.assignedAuthority,
      claimantName: claimantName ?? this.claimantName,
      claimantNameEn: claimantNameEn ?? this.claimantNameEn,
      fatherHusbandName: fatherHusbandName ?? this.fatherHusbandName,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      claimDescription: claimDescription ?? this.claimDescription,
      surveyNumber: surveyNumber ?? this.surveyNumber,
      areaSqMeters: areaSqMeters ?? this.areaSqMeters,
      landDescription: landDescription ?? this.landDescription,
      cfrBoundaryGeoJson: cfrBoundaryGeoJson ?? this.cfrBoundaryGeoJson,
      occupationYears: occupationYears ?? this.occupationYears,
      occupationBefore2005: occupationBefore2005 ?? this.occupationBefore2005,
      evidenceFlags: evidenceFlags ?? this.evidenceFlags,
      evidenceScore: evidenceScore ?? this.evidenceScore,
      missingEvidence: missingEvidence ?? this.missingEvidence,
      evidenceList: evidenceList ?? this.evidenceList,
      frcFindings: frcFindings ?? this.frcFindings,
      gramSabhaReview: gramSabhaReview ?? this.gramSabhaReview,
      forestVerification: forestVerification ?? this.forestVerification,
      revenueVerification: revenueVerification ?? this.revenueVerification,
      sdlcReview: sdlcReview ?? this.sdlcReview,
      dlcDecision: dlcDecision ?? this.dlcDecision,
      annexureIV: annexureIV ?? this.annexureIV,
      recordIncorporation: recordIncorporation ?? this.recordIncorporation,
      auditTrail: auditTrail ?? this.auditTrail,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      appealDeadline: appealDeadline ?? this.appealDeadline,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'claimantUserId': claimantUserId,
        'villageId': villageId,
        'villageName': villageName,
        'gramPanchayat': gramPanchayat,
        'tehsil': tehsil,
        'district': district,
        'state': state,
        'type': type.name,
        'status': status.name,
        'nature': nature.name,
        'assignedAuthority': assignedAuthority.name,
        'claimantName': claimantName,
        'claimantNameEn': claimantNameEn,
        'fatherHusbandName': fatherHusbandName,
        'address': address,
        'contactPhone': contactPhone,
        'claimDescription': claimDescription,
        'surveyNumber': surveyNumber,
        'areaSqMeters': areaSqMeters,
        'landDescription': landDescription,
        'cfrBoundaryGeoJson': cfrBoundaryGeoJson,
        'occupationYears': occupationYears,
        'occupationBefore2005': occupationBefore2005,
        'evidenceFlags': evidenceFlags,
        'evidenceScore': evidenceScore,
        'missingEvidence': missingEvidence,
        'evidenceList': evidenceList.map((e) => e.toJson()).toList(),
        'frcFindings': frcFindings?.toJson(),
        'gramSabhaReview': gramSabhaReview?.toJson(),
        'forestVerification': forestVerification?.toJson(),
        'revenueVerification': revenueVerification?.toJson(),
        'sdlcReview': sdlcReview?.toJson(),
        'dlcDecision': dlcDecision?.toJson(),
        'annexureIV': annexureIV?.toJson(),
        'recordIncorporation': recordIncorporation?.toJson(),
        'auditTrail': auditTrail.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
        'submittedAt': submittedAt?.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
        'rejectedAt': rejectedAt?.toIso8601String(),
        'rejectionReason': rejectionReason,
        'appealDeadline': appealDeadline?.toIso8601String(),
        'isSynced': isSynced,
      };

  Map<String, dynamic> toFirestore() => {
        ...toJson(),
        'createdAt': Timestamp.fromDate(createdAt),
        'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt ?? DateTime.now()),
        'submittedAt':
            submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
        'reviewedAt':
            reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
        'rejectedAt':
            rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
        'appealDeadline':
            appealDeadline != null ? Timestamp.fromDate(appealDeadline!) : null,
        'isSynced': true,
      };

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  static DateTime? _parseDateOrNull(dynamic value) {
    if (value == null) return null;
    return _parseDate(value);
  }

  factory Claim.fromJson(Map<String, dynamic> json) => Claim(
        id: json['id'] as String,
        claimantUserId: json['claimantUserId'] as String? ?? '',
        villageId: json['villageId'] as String? ?? '',
        villageName: json['villageName'] as String? ?? 'ओझर (Ozhar)',
        gramPanchayat: json['gramPanchayat'] as String? ?? 'ओझर (Ozhar)',
        tehsil: json['tehsil'] as String? ?? 'जव्हार (Jawhar)',
        district: json['district'] as String? ?? 'पालघर (Palghar)',
        state: json['state'] as String? ?? 'महाराष्ट्र (Maharashtra)',
        type: json['type'] == 'formB' ? ClaimType.formB : ClaimType.formA,
        status: ClaimStatusExtension.parse(json['status'] as String?),
        nature: ClaimNatureExtension.parse(json['nature'] as String?),
        assignedAuthority:
            UserRoleExtension.parse(json['assignedAuthority'] as String?),
        claimantName: json['claimantName'] as String? ?? '',
        claimantNameEn: json['claimantNameEn'] as String? ?? '',
        fatherHusbandName: json['fatherHusbandName'] as String?,
        address: json['address'] as String?,
        contactPhone: json['contactPhone'] as String?,
        claimDescription: json['claimDescription'] as String?,
        surveyNumber: json['surveyNumber'] as String?,
        areaSqMeters: (json['areaSqMeters'] as num?)?.toDouble(),
        landDescription: json['landDescription'] as String?,
        cfrBoundaryGeoJson:
            json['cfrBoundaryGeoJson'] as Map<String, dynamic>?,
        occupationYears: json['occupationYears'] as int?,
        occupationBefore2005: json['occupationBefore2005'] as bool? ?? true,
        evidenceFlags: (json['evidenceFlags'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as bool)) ??
            const {},
        evidenceScore: (json['evidenceScore'] as num?)?.toDouble() ?? 0.0,
        missingEvidence: (json['missingEvidence'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
        evidenceList: (json['evidenceList'] as List<dynamic>?)
                ?.map((e) =>
                    ClaimEvidenceItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        frcFindings: json['frcFindings'] != null
            ? FrcFindings.fromJson(json['frcFindings'] as Map<String, dynamic>)
            : null,
        gramSabhaReview: json['gramSabhaReview'] != null
            ? GramSabhaReviewData.fromJson(
                json['gramSabhaReview'] as Map<String, dynamic>)
            : null,
        forestVerification: json['forestVerification'] != null
            ? FieldVerificationRecord.fromJson(
                json['forestVerification'] as Map<String, dynamic>)
            : null,
        revenueVerification: json['revenueVerification'] != null
            ? FieldVerificationRecord.fromJson(
                json['revenueVerification'] as Map<String, dynamic>)
            : null,
        sdlcReview: json['sdlcReview'] != null
            ? SdlcReviewData.fromJson(
                json['sdlcReview'] as Map<String, dynamic>)
            : null,
        dlcDecision: json['dlcDecision'] != null
            ? DlcDecisionData.fromJson(
                json['dlcDecision'] as Map<String, dynamic>)
            : null,
        annexureIV: json['annexureIV'] != null
            ? AnnexureIVData.fromJson(
                json['annexureIV'] as Map<String, dynamic>)
            : null,
        recordIncorporation: json['recordIncorporation'] != null
            ? RecordIncorporationData.fromJson(
                json['recordIncorporation'] as Map<String, dynamic>)
            : null,
        auditTrail: (json['auditTrail'] as List<dynamic>?)
                ?.map((e) => WorkflowEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        createdAt: _parseDate(json['createdAt']),
        lastUpdatedAt: _parseDateOrNull(json['lastUpdatedAt']),
        submittedAt: _parseDateOrNull(json['submittedAt']),
        reviewedAt: _parseDateOrNull(json['reviewedAt']),
        rejectedAt: _parseDateOrNull(json['rejectedAt']),
        rejectionReason: json['rejectionReason'] as String?,
        appealDeadline: _parseDateOrNull(json['appealDeadline']),
        isSynced: json['isSynced'] as bool? ?? false,
      );
}
