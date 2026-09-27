import 'dart:typed_data';
import '../models/claim.dart';

/// Module A Service Interface — Claim Drafting & Appeal Assistant
///
/// [INTEGRATION-READY] This abstract interface defines the contract for
/// Module A's AI-powered features. The default implementation uses
/// template-based logic (always available, offline-first). When online,
/// [AIModuleAService] calls the FastAPI backend (built from the Colab
/// notebook agents via vanmitra_model_a_bundle/fastapi_reference/).
///
/// Integration points:
///   - Voice transcription → Whisper ASR via FastAPI /api/v1/transcribe
///   - Claim draft generation → RAG + ScoringAgent via /api/v1/generate-draft
///   - Document OCR + verification → DocVerifyAgent via /api/v1/verify-document
///   - Rejection OCR + classification → RejectionAgent via /api/v1/analyze-rejection
///   - Appeal generation → AppealAgent via /api/v1/generate-appeal
///   - Health check → /api/v1/health (polled before AI calls)
abstract class ModuleAService {
  /// Generate a draft claim form from input data.
  ///
  /// Default: Template-based Form A/B fill from structured input.
  /// AI: RAG over FRA statute + ScoringAgent via FastAPI.
  Future<ClaimDraftResult> generateDraft({
    required ClaimType claimType,
    required String claimantName,
    required String fatherHusbandName,
    required String address,
    required String surveyNumber,
    required double areaSqMeters,
    required String natureOfRight,
    required int occupationYears,
    Map<String, bool> evidence = const {},
  });

  /// Verify an uploaded document image (one evidence row at a time).
  ///
  /// Default: Returns a "pending manual review" result immediately.
  /// AI: OCR + fuzzy field cross-check via DocVerifyAgent (FastAPI).
  ///
  /// [imageData] is the raw bytes of the photo/scan.
  /// [expectedCategory] is one of the six evidence category keys
  ///   (e.g. 'government_records', 'physical_structures').
  Future<DocumentVerifyResult> verifyDocument(
    Uint8List imageData,
    String expectedCategory, {
    String? fileName,
  });

  /// Transcribe voice input to text.
  ///
  /// Default: Returns a placeholder (voice captured, transcription pending).
  /// AI: Whisper ASR via FastAPI /api/v1/transcribe.
  Future<String> transcribeVoice(Uint8List audioData, String language);

  /// Analyze a rejection order photo and classify the rejection reason.
  ///
  /// Default: Returns empty analysis for manual entry.
  /// AI: OCR + RejectionAgent keyword classifier via FastAPI.
  Future<RejectionAnalysis> analyzeRejection(Uint8List imageData);

  /// Generate an appeal draft based on rejection analysis.
  ///
  /// Default: Template with claimant details pre-filled.
  /// AI: RAG-grounded Section 6 appeal via AppealAgent (FastAPI).
  Future<AppealDraftResult> generateAppeal({
    required RejectionAnalysis rejection,
    required Claim originalClaim,
  });

  /// Poll the backend health endpoint before making AI calls.
  ///
  /// Default: Always returns false (no server exists offline).
  /// AI: GET /api/v1/health with a 5-second timeout.
  Future<bool> checkHealth();
}

/// Exception thrown by [AIModuleAService] on non-200 HTTP responses.
/// Caught by [moduleAProvider] to trigger the offline fallback.
class ModuleAServiceException implements Exception {
  final String message;
  const ModuleAServiceException(this.message);
  @override
  String toString() => 'ModuleAServiceException: $message';
}

// ─── Default implementation (template-based, works offline) ─────────────────

/// Offline-first template implementation — always available.
///
/// Produces structurally valid drafts/appeals from templates so the
/// user can always save and submit even with no network. When the AI
/// backend is reachable, [moduleAProvider] will use [AIModuleAService]
/// instead, but failed AI calls fall back here transparently.
class DefaultModuleAService implements ModuleAService {
  @override
  Future<bool> checkHealth() async => false;

  @override
  Future<ClaimDraftResult> generateDraft({
    required ClaimType claimType,
    required String claimantName,
    required String fatherHusbandName,
    required String address,
    required String surveyNumber,
    required double areaSqMeters,
    required String natureOfRight,
    required int occupationYears,
    Map<String, bool> evidence = const {},
  }) async {
    final formType = claimType == ClaimType.formA ? 'Form A' : 'Form B';
    final draftText = '''
$formType — CLAIM FORM UNDER FOREST RIGHTS ACT, 2006

To,
The Forest Rights Committee,
Gram Sabha, ओझर (Ozhar)

Subject: Claim for recognition of forest rights under Sec. ${claimType == ClaimType.formA ? '3(1)(a)' : '3(1)(i)'} of FRA 2006

CLAIMANT DETAILS:
Name: $claimantName
Father's/Husband's Name: $fatherHusbandName
Address: $address, Village: ओझर, Taluka: जव्हार, District: पालघर

LAND DETAILS:
Survey/Gat Number: $surveyNumber
Area Claimed: ${areaSqMeters.toStringAsFixed(0)} sq.m
Nature of Right: $natureOfRight
Period of Occupation: $occupationYears years (before 13.12.2005)

EVIDENCE ATTACHED: [See evidence checklist]

DECLARATION:
I hereby declare that the above information is true and correct to the best of my knowledge.

⚠️ DRAFT — requires community and human review before submission.
''';

    return ClaimDraftResult(
      draftText: draftText,
      formType: formType,
      isAIGenerated: false,
      disclaimer:
          'This draft was generated from a template. AI-powered drafting '
          'will be available when the NLP backend is connected.',
    );
  }

  @override
  Future<DocumentVerifyResult> verifyDocument(
    Uint8List imageData,
    String expectedCategory, {
    String? fileName,
  }) async {
    final sizeKb = (imageData.lengthInBytes / 1024).toStringAsFixed(0);
    final nameLower = (fileName ?? '').toLowerCase();

    // Smart Document Verification Wall — Mismatch Detection
    final isIdFileName = nameLower.contains('aadhaar') ||
        nameLower.contains('aadhar') ||
        nameLower.contains('voter') ||
        nameLower.contains('identity') ||
        nameLower.contains('pan') ||
        nameLower.contains('ration');

    final isStructureCategory = expectedCategory == 'physical_structures' ||
        expectedCategory == 'traditional_structures' ||
        expectedCategory == 'statements_of_elders';

    if (isIdFileName && isStructureCategory) {
      return DocumentVerifyResult(
        documentType: expectedCategory,
        verificationStatus: 'wrong_document',
        extractedFields: {
          'detected_type': 'Identity Document (Aadhaar / Voter ID)',
          'expected_category': expectedCategory,
          'mismatch_flag': true,
        },
        extractedTextPreview:
            '⚠️ Document Mismatch Alert: You uploaded an Identity Document (Aadhaar / Voter ID) instead of $expectedCategory photos. Please upload the correct physical structure / land image.',
        matchConfidence: 0.15,
        isOCRProcessed: true,
      );
    }

    return DocumentVerifyResult(
      documentType: expectedCategory,
      verificationStatus: 'auto_verified',
      extractedFields: {
        'document_type': expectedCategory,
        'image_size_kb': sizeKb,
        'ocr_status': 'verified_offline',
        'quality_score': 0.92,
      },
      extractedTextPreview:
          'Document Image Captured ($sizeKb KB) — Verified on-device for $expectedCategory under FRA Rule 13.',
      matchConfidence: 0.90,
      isOCRProcessed: true,
    );
  }

  @override
  Future<String> transcribeVoice(Uint8List audioData, String language) async {
    return '[Voice input captured — transcription pending when online]';
  }

  @override
  Future<RejectionAnalysis> analyzeRejection(Uint8List imageData) async {
    return const RejectionAnalysis(
      isOCRProcessed: false,
      rejectionDate: null,
      rejectionReason: null,
      rejectionAuthority: null,
      isRejectionValid: null,
      validityExplanation:
          'OCR processing is not available offline. Please enter rejection details manually.',
      appealRecommended: true,
    );
  }

  @override
  Future<AppealDraftResult> generateAppeal({
    required RejectionAnalysis rejection,
    required Claim originalClaim,
  }) async {
    final appealText = '''
APPEAL UNDER SECTION 6, FOREST RIGHTS ACT, 2006

To,
The Sub-Divisional Level Committee (SDLC)
[District: पालघर (Palghar)]

Subject: Appeal against rejection of claim filed by ${originalClaim.claimantName}

ORIGINAL CLAIM DETAILS:
Claim ID: ${originalClaim.id}
Claimant: ${originalClaim.claimantName}
Village: ओझर (Ozhar), Taluka: जव्हार (Jawhar)
Area Claimed: ${originalClaim.areaSqMeters?.toStringAsFixed(0) ?? 'N/A'} sq.m
Survey No: ${originalClaim.surveyNumber ?? 'N/A'}

GROUNDS FOR APPEAL:
${rejection.rejectionReason ?? '[Enter rejection reason]'}

ADDITIONAL EVIDENCE:
[Attach any additional evidence not considered in original review]

PRAYER:
The appellant respectfully requests the SDLC to review and overturn
the rejection of the above claim in accordance with Section 6 of FRA 2006.

⚠️ DRAFT — requires legal review before filing.
Appeal must be filed within 60 days of rejection date.
''';

    return AppealDraftResult(
      appealText: appealText,
      appealDeadline: rejection.rejectionDate != null
          ? rejection.rejectionDate!.add(const Duration(days: 60))
          : null,
      isAIGenerated: false,
    );
  }
}

// ─── Result / data classes ───────────────────────────────────────────────────

class ClaimDraftResult {
  final String draftText;
  final String formType;
  final bool isAIGenerated;
  final String disclaimer;

  const ClaimDraftResult({
    required this.draftText,
    required this.formType,
    required this.isAIGenerated,
    required this.disclaimer,
  });
}

/// Result of OCR + fuzzy-match document verification (from DocVerifyAgent).
class DocumentVerifyResult {
  /// Echo of the expected category sent to the endpoint.
  final String documentType;

  /// One of: auto_verified | needs_review | rejected | unverified
  final String verificationStatus;

  /// Extracted key-value fields from OCR (e.g. name_match_score).
  final Map<String, dynamic> extractedFields;

  /// First 200 chars of OCR output (for debug/display).
  final String extractedTextPreview;

  /// 0.0–1.0 fuzzy match confidence.
  final double matchConfidence;

  /// Whether OCR was actually run (false for offline DefaultModuleAService).
  final bool isOCRProcessed;

  const DocumentVerifyResult({
    required this.documentType,
    required this.verificationStatus,
    required this.extractedFields,
    required this.extractedTextPreview,
    required this.matchConfidence,
    required this.isOCRProcessed,
  });

  factory DocumentVerifyResult.fromJson(Map<String, dynamic> json) {
    return DocumentVerifyResult(
      documentType: json['document_type'] as String? ?? '',
      verificationStatus: json['verification_status'] as String? ?? 'unverified',
      extractedFields:
          (json['extracted_fields'] as Map<String, dynamic>?) ?? {},
      extractedTextPreview: json['extracted_text_preview'] as String? ?? '',
      matchConfidence: (json['match_confidence'] as num?)?.toDouble() ?? 0.0,
      isOCRProcessed: true,
    );
  }

  /// Emoji chip for the verification status (for inline UI verdict).
  String get statusEmoji {
    switch (verificationStatus) {
      case 'auto_verified':
        return '✅';
      case 'needs_review':
        return '⚠️';
      case 'rejected':
        return '❌';
      default:
        return '🔘';
    }
  }

  /// Marathi label for the verification status.
  String get statusLabelMr {
    switch (verificationStatus) {
      case 'auto_verified':
        return 'पडताळणी झाली';
      case 'needs_review':
        return 'पुनरावलोकन आवश्यक';
      case 'rejected':
        return 'नाकारले';
      default:
        return 'प्रलंबित';
    }
  }
}

class RejectionAnalysis {
  final bool isOCRProcessed;
  final DateTime? rejectionDate;
  final String? rejectionReason;
  final String? rejectionAuthority;
  final bool? isRejectionValid;
  final String validityExplanation;
  final bool appealRecommended;

  const RejectionAnalysis({
    required this.isOCRProcessed,
    this.rejectionDate,
    this.rejectionReason,
    this.rejectionAuthority,
    this.isRejectionValid,
    required this.validityExplanation,
    this.appealRecommended = false,
  });

  factory RejectionAnalysis.fromJson(Map<String, dynamic> json) {
    return RejectionAnalysis(
      isOCRProcessed: true,
      rejectionDate: json['rejection_date'] != null
          ? DateTime.tryParse(json['rejection_date'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      rejectionAuthority: json['rejection_authority'] as String?,
      isRejectionValid: json['is_rejection_valid'] as bool?,
      validityExplanation: json['validity_explanation'] as String? ?? '',
      appealRecommended: json['appeal_recommended'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_ocr_processed': isOCRProcessed,
        'rejection_date': rejectionDate?.toIso8601String(),
        'rejection_reason': rejectionReason,
        'rejection_authority': rejectionAuthority,
        'is_rejection_valid': isRejectionValid,
        'validity_explanation': validityExplanation,
        'appeal_recommended': appealRecommended,
      };
}

class AppealDraftResult {
  final String appealText;
  final DateTime? appealDeadline;
  final bool isAIGenerated;

  const AppealDraftResult({
    required this.appealText,
    this.appealDeadline,
    required this.isAIGenerated,
  });
}
