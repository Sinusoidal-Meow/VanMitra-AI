import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/core/api/api_endpoints.dart';

class CaseHubApi {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getMyCases() async {
    final res = await _api.get(ApiEndpoints.myCases);
    return res as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getVillageCases(String villageId) async {
    final res = await _api.get(ApiEndpoints.villageCases(villageId));
    return res as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getReviewQueue() async {
    final res = await _api.get(ApiEndpoints.reviewQueue);
    return res as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createCase(
      String villageId, String claimType) async {
    final res = await _api.post(
      ApiEndpoints.villageCases(villageId),
      body: {'claim_type': claimType},
    );
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCaseDetails(String caseId) async {
    final res = await _api.get(ApiEndpoints.caseDetails(caseId));
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitCase(String caseId) async {
    final res = await _api.post(ApiEndpoints.submitCase(caseId));
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveCase(String caseId) async {
    final res = await _api.post(ApiEndpoints.approveCase(caseId));
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> returnCase(String caseId, String remarks) async {
    final res = await _api.post(
      ApiEndpoints.returnCase(caseId),
      body: {'remarks': remarks},
    );
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectCase(String caseId, String remarks) async {
    final res = await _api.post(
      ApiEndpoints.rejectCase(caseId),
      body: {'remarks': remarks},
    );
    return res as Map<String, dynamic>;
  }

  /// Every action on the claim, oldest first.
  Future<List<dynamic>> history(String caseId) async =>
      (await _api.get(ApiEndpoints.caseHistory(caseId)) as List<dynamic>?) ?? [];

  /// Receipt data (serial, date); 409 NOT_YET_FILED before the claim is submitted.
  Future<Map<String, dynamic>> acknowledgement(String caseId) async =>
      await _api.get(ApiEndpoints.acknowledgement(caseId)) as Map<String, dynamic>;

  /// Annexure title draft; 409 TITLE_NOT_AVAILABLE before the district stage.
  Future<Map<String, dynamic>> titleDraft(String caseId) async =>
      await _api.get(ApiEndpoints.titleDraft(caseId)) as Map<String, dynamic>;

  /// Joint field verification visits (recorded by the Gram Sabha).
  Future<List<dynamic>> verifications(String caseId) async =>
      (await _api.get(ApiEndpoints.verification(caseId)) as List<dynamic>?) ?? [];

  /// Gram Sabha resolutions on this claim.
  Future<List<dynamic>> resolutions(String caseId) async =>
      (await _api.get(ApiEndpoints.caseResolutions(caseId)) as List<dynamic>?) ?? [];

  /// What the Gram Sabha still needs before forwarding a Form C claim.
  Future<Map<String, dynamic>> approvalCheck(String caseId) async =>
      await _api.get(ApiEndpoints.approvalCheck(caseId)) as Map<String, dynamic>;

  /// The village's Gram Sabha meetings, newest first.
  Future<List<dynamic>> meetings(String villageId) async =>
      (await _api.get(ApiEndpoints.meetings(villageId)) as List<dynamic>?) ?? [];

  /// The three quorum tests for a meeting [Rule 4(2)].
  Future<Map<String, dynamic>> quorum(String meetingId) async =>
      await _api.get(ApiEndpoints.quorum(meetingId)) as Map<String, dynamic>;

  /// Re-check the village's tamper-evident record chain.
  Future<Map<String, dynamic>> ledgerVerify(String villageId) async =>
      await _api.get(ApiEndpoints.ledgerVerify(villageId)) as Map<String, dynamic>;

  /// Server and database reachable?
  Future<bool> health() async {
    final res = await _api.get(ApiEndpoints.health, requireAuth: false);
    return res is Map && res['status'] == 'ok';
  }
}
