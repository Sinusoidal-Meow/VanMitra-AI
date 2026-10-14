import '../../../core/api/api_client.dart';
import 'livelihood_api.dart';

/// Turn a failure into the key of a plain-language message. The app never shows a raw error code
/// (the host's rule): every server `message_key` we know has words, and anything else gets a
/// calm generic line.
String errorMessageKey(Object error) {
  if (error is NetworkException) return 'lv_err_offline';
  if (error is ApiException) {
    switch (error.messageKey) {
      case 'auth.required':
      case 'auth.token_expired':
      case 'auth.token_invalid':
        return 'lv_err_signin';
      case 'livelihood.role_not_allowed':
        return 'lv_err_role';
      case 'livelihood.no_village':
      case 'livelihood.village_not_found':
        return 'lv_err_no_village';
      case 'livelihood.data_not_loaded':
        return 'lv_err_data';
      case 'livelihood.location_outside_maharashtra':
        return 'lv_err_outside_mh';
      case 'livelihood.radius_too_large':
      case 'livelihood.invalid_radius':
        return 'lv_err_radius';
    }
    return error.statusCode >= 500 ? 'lv_err_server' : 'lv_err_generic';
  }
  return 'lv_err_generic';
}
