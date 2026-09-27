import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'module_a_service.dart';
import '../models/claim.dart';

/// Network-backed implementation of [ModuleAService].
///
/// Makes HTTP calls to the VanMitra FastAPI backend when available.
/// If the backend is unreachable or offline, automatically falls back
/// to [DefaultModuleAService] for seamless offline-first execution.
class AIModuleAService implements ModuleAService {
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;
  final _fallbackService = DefaultModuleAService();

  AIModuleAService({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 4),
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ─── Health ────────────────────────────────────────────────────────────────

  @override
  Future<bool> checkHealth() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/api/v1/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Draft generation ─────────────────────────────────────────────────────

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
    try {
      final payload = {
        'form_type': claimType == ClaimType.formA ? 'A' : 'B',
        'claimant_name': claimantName,
        'father_husband_name': fatherHusbandName,
        'survey_number': surveyNumber,
        'area_sq_meters': areaSqMeters,
        'nature_of_right': natureOfRight,
        'occupation_years': occupationYears,
        'language': 'mr',
      };

      final res = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/generate-draft'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return ClaimDraftResult(
          draftText: body['draft_text'] as String,
          formType: body['form_type'] as String? ?? payload['form_type'] as String,
          isAIGenerated: body['is_ai_generated'] as bool? ?? true,
          disclaimer: body['disclaimer'] as String? ??
              'AI-generated draft — please review before submission.',
        );
      }
    } catch (e) {
      print('AIModuleAService.generateDraft: Backend unreachable ($e). Falling back to offline template.');
    }

    return _fallbackService.generateDraft(
      claimType: claimType,
      claimantName: claimantName,
      fatherHusbandName: fatherHusbandName,
      address: address,
      surveyNumber: surveyNumber,
      areaSqMeters: areaSqMeters,
      natureOfRight: natureOfRight,
      occupationYears: occupationYears,
      evidence: evidence,
    );
  }

  // ─── Document verification ────────────────────────────────────────────────

  @override
  Future<DocumentVerifyResult> verifyDocument(
    Uint8List imageData,
    String expectedCategory, {
    String? fileName,
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/verify-document'),
      )
        ..fields['expected_category'] = expectedCategory
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageData,
          filename: fileName ?? 'document.jpg',
        ));

      final streamed = await req.send().timeout(timeout);
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        return DocumentVerifyResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      print('AIModuleAService.verifyDocument: Backend unreachable ($e). Falling back to on-device offline verification.');
    }

    return _fallbackService.verifyDocument(imageData, expectedCategory, fileName: fileName);
  }

  // ─── Voice transcription ──────────────────────────────────────────────────

  @override
  Future<String> transcribeVoice(Uint8List audioData, String language) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/transcribe'),
      )
        ..fields['language'] = language
        ..files.add(http.MultipartFile.fromBytes(
          'audio',
          audioData,
          filename: 'clip.wav',
        ));

      final streamed = await req.send().timeout(timeout);
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as Map<String, dynamic>)['text'] as String;
      }
    } catch (e) {
      print('AIModuleAService.transcribeVoice: Backend unreachable ($e). Falling back to offline handler.');
    }

    return _fallbackService.transcribeVoice(audioData, language);
  }

  // ─── Rejection analysis ───────────────────────────────────────────────────

  @override
  Future<RejectionAnalysis> analyzeRejection(Uint8List imageData) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/analyze-rejection'),
      )
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageData,
          filename: 'order.jpg',
        ));

      final streamed = await req.send().timeout(timeout);
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        return RejectionAnalysis.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      print('AIModuleAService.analyzeRejection: Backend unreachable ($e). Falling back to offline analysis.');
    }

    return _fallbackService.analyzeRejection(imageData);
  }

  // ─── Appeal generation ────────────────────────────────────────────────────

  @override
  Future<AppealDraftResult> generateAppeal({
    required RejectionAnalysis rejection,
    required Claim originalClaim,
  }) async {
    try {
      final payload = {
        'rejection_analysis': rejection.toJson(),
        'original_claim': {
          'form_type': originalClaim.type == ClaimType.formA ? 'A' : 'B',
          'claimant_name': originalClaim.claimantName,
          'father_husband_name': originalClaim.fatherHusbandName ?? '',
          'survey_number': originalClaim.surveyNumber,
          'area_sq_meters': originalClaim.areaSqMeters ?? 0.0,
          'nature_of_right': originalClaim.nature.name,
          'occupation_years': originalClaim.occupationYears ?? 0,
          'language': 'mr',
        },
      };

      final res = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/generate-appeal'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return AppealDraftResult(
          appealText: body['appeal_text'] as String,
          appealDeadline: body['appeal_deadline'] != null
              ? DateTime.parse(body['appeal_deadline'] as String)
              : null,
          isAIGenerated: body['is_ai_generated'] as bool? ?? true,
        );
      }
    } catch (e) {
      print('AIModuleAService.generateAppeal: Backend unreachable ($e). Falling back to offline appeal generator.');
    }

    return _fallbackService.generateAppeal(
      rejection: rejection,
      originalClaim: originalClaim,
    );
  }

  void dispose() => _client.close();
}
