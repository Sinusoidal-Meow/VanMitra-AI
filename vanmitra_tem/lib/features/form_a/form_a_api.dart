import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import 'form_a_models.dart';

class FormAApi {
  final ApiClient _apiClient;

  FormAApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<FormAData> getFormA(String caseId) async {
    final res = await _apiClient.get(ApiEndpoints.formA(caseId));
    return FormAData.fromJson(res as Map<String, dynamic>);
  }

  Future<FormAData> saveFormA(String caseId, Map<String, dynamic> body) async {
    final res = await _apiClient.put(ApiEndpoints.formA(caseId), body: body);
    return FormAData.fromJson(res as Map<String, dynamic>);
  }
}

final formAApi = FormAApi();
