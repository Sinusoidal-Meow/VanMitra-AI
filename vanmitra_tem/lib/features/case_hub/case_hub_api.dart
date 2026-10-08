import 'package:vanmitra_ai/core/api/api_client.dart';
import 'package:vanmitra_ai/core/api/api_endpoints.dart';
import 'package:vanmitra_ai/models/claim.dart';

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

  Future<Map<String, dynamic>> createCase(String villageId, String claimType) async {
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
}
