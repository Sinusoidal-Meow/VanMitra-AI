// Evidence ledger [Rule 13], readiness checklist and media upload on the VanMitra backend.

import 'dart:typed_data';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class EvidenceApi {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> list(String caseId) async {
    final res = await _api.get(ApiEndpoints.evidence(caseId)) as List<dynamic>?;
    return (res ?? []).cast<Map<String, dynamic>>();
  }

  /// Record one evidence item. [body] follows EvidenceCreate on the server.
  Future<Map<String, dynamic>> add(String caseId, Map<String, dynamic> body) async =>
      await _api.post(ApiEndpoints.evidence(caseId), body: body) as Map<String, dynamic>;

  /// Documentation completeness (R1–R10 for Form C; the ones that apply for Form B).
  Future<Map<String, dynamic>> readiness(String caseId) async =>
      await _api.get(ApiEndpoints.readiness(caseId)) as Map<String, dynamic>;

  /// Upload a photo / PDF; returns the media record (its `id` goes into evidence).
  Future<Map<String, dynamic>> uploadMedia({
    required Uint8List bytes,
    required String filename,
    required String mime,
    double? lat,
    double? lon,
    double? accuracyM,
    DateTime? capturedAt,
  }) async {
    final fields = <String, String>{
      if (lat != null) 'gps_lat': lat.toString(),
      if (lon != null) 'gps_lon': lon.toString(),
      if (accuracyM != null) 'gps_accuracy_m': accuracyM.toString(),
      if (capturedAt != null) 'captured_at': capturedAt.toUtc().toIso8601String(),
    };
    return await _api.upload(ApiEndpoints.media,
        bytes: bytes, filename: filename, mime: mime, fields: fields) as Map<String, dynamic>;
  }

  Future<Uint8List> mediaBytes(String mediaId) async =>
      Uint8List.fromList(await _api.getBytes(ApiEndpoints.mediaFile(mediaId)));

  /// Gram Sabha member list (to pick the elder for an elder statement).
  Future<List<Map<String, dynamic>>> members(String villageId) async {
    final res = await _api.get(ApiEndpoints.members(villageId)) as List<dynamic>?;
    return (res ?? []).cast<Map<String, dynamic>>();
  }
}

/// Kinds of evidence a villager records from the phone (server: EvidenceKind).
const Map<String, String> kEvidenceKinds = {
  'photo': 'Photo',
  'document_scan': 'Document scan',
  'text_note': 'Written note',
  'elder_statement': 'Elder statement',
};

/// Plain words for the readiness checklist (server: readiness.*).
const Map<String, String> kReadinessText = {
  'readiness.r1_two_general_evidences': 'At least two Rule 13(1) evidences, verified by the FRC',
  'readiness.r2_cfr_evidence': 'At least one community-forest evidence (Rule 13(2)), verified',
  'readiness.r3_boundary_approved': 'Boundary approved by the Gram Sabha',
  'readiness.r4_landmark_per_segment': 'A landmark on every side of the boundary',
  'readiness.r5_field_verification': 'Joint field verification completed',
  'readiness.r6_elder_statement': 'Signed statement of elders (or enough other evidence)',
  'readiness.r7_quorum': 'Gram Sabha meeting with quorum',
  'readiness.r8_adjoining_intimated': 'Neighbouring Gram Sabhas informed',
  'readiness.r9_acknowledged': 'Claim acknowledged with a receipt',
  'readiness.r10_no_open_dispute': 'No open boundary dispute with a neighbour',
};
