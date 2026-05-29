import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// `POST /api/v1/settings/vendors/model-test` — OpenAPI `postSettingsVendorModelTestV1`.
/// **200** = **`queued`** **`JobRow`** (**`settings.vendor.model_test`**); **429**/**503** as elsewhere.
Future<int> postSettingsVendorModelTestV1(
  String accessToken, {
  required String modelName,
  required String type,
  required String id,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/model-test');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'modelName': modelName, 'type': type, 'id': id}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// OpenAPI vendor mutation response shared by add/update/delete/update-code flows.
class VendorMutationResponseV1 {
  const VendorMutationResponseV1({
    required this.vendorId,
    required this.message,
    this.enabled,
    this.link,
  });

  final String vendorId;
  final String message;
  final bool? enabled;
  final String? link;

  factory VendorMutationResponseV1.fromJson(Map<String, dynamic> json) {
    return VendorMutationResponseV1(
      vendorId: json['vendorId'] as String,
      message: json['message'] as String? ?? '',
      enabled: json['enabled'] as bool?,
      link: json['link'] as String?,
    );
  }
}

Future<VendorMutationResponseV1> _decodeVendorMutationResponse(
  http.Response res,
) async {
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VendorMutationResponseV1.fromJson(map);
}

/// `POST /api/v1/settings/vendors/update` — OpenAPI `postSettingsVendorsUpdateV1`.
Future<VendorMutationResponseV1> postSettingsVendorsUpdateV1(
  String accessToken, {
  required String id,
  String? displayName,
  List<String> selectedModels = const [],
  Map<String, String> settings = const {},
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/update');
  final body = <String, dynamic>{'id': id};
  if (displayName != null) {
    body['displayName'] = displayName;
  }
  if (selectedModels.isNotEmpty) {
    body['selectedModels'] = selectedModels;
  }
  if (settings.isNotEmpty) {
    body['settings'] = settings;
  }
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  return _decodeVendorMutationResponse(res);
}

/// `POST /api/v1/settings/vendors/delete` — OpenAPI `postSettingsVendorsDeleteV1`.
Future<VendorMutationResponseV1> postSettingsVendorsDeleteV1(
  String accessToken, {
  required String id,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/delete');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'id': id}),
      )
      .timeout(const Duration(seconds: 15));
  return _decodeVendorMutationResponse(res);
}

/// `POST /api/v1/settings/vendors/enable` — OpenAPI `postSettingsVendorsEnableV1`.
Future<VendorMutationResponseV1> postSettingsVendorsEnableV1(
  String accessToken, {
  required String id,
  required num enable,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/enable');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'id': id, 'enable': enable}),
      )
      .timeout(const Duration(seconds: 15));
  return _decodeVendorMutationResponse(res);
}

/// `POST /api/v1/settings/vendors/update-code` — OpenAPI `postSettingsVendorsUpdateCodeV1`.
Future<VendorMutationResponseV1> postSettingsVendorsUpdateCodeV1(
  String accessToken, {
  required String id,
  required String tsCode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/update-code');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'id': id, 'tsCode': tsCode}),
      )
      .timeout(const Duration(seconds: 15));
  return _decodeVendorMutationResponse(res);
}

/// `POST /api/v1/settings/vendors/code-from-link` — OpenAPI `postSettingsVendorsCodeFromLinkV1`.
Future<VendorMutationResponseV1> postSettingsVendorsCodeFromLinkV1(
  String accessToken, {
  required String link,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/code-from-link');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'link': link}),
      )
      .timeout(const Duration(seconds: 15));
  return _decodeVendorMutationResponse(res);
}

/// `POST /api/v1/settings/vendors/add` — OpenAPI `postSettingsVendorsAddV1`.
Future<VendorMutationResponseV1> postSettingsVendorsAddV1(
  String accessToken, {
  required String tsCode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/add');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'tsCode': tsCode}),
      )
      .timeout(const Duration(seconds: 15));
  return _decodeVendorMutationResponse(res);
}
