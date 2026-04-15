import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'vendors_mutations.dart';

/// OpenAPI `VendorCredentialResponse` — encrypted vendor credential metadata only.
class VendorCredentialResponseV1 {
  const VendorCredentialResponseV1({
    required this.vendorId,
    required this.hasSecret,
    required this.hasToken,
    required this.message,
    this.keyHint,
  });

  final String vendorId;
  final bool hasSecret;
  final bool hasToken;
  final String message;
  final String? keyHint;

  factory VendorCredentialResponseV1.fromJson(Map<String, dynamic> json) {
    return VendorCredentialResponseV1(
      vendorId: json['vendorId'] as String,
      hasSecret: json['hasSecret'] as bool? ?? false,
      hasToken: json['hasToken'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      keyHint: json['keyHint'] as String?,
    );
  }
}

Future<VendorCredentialResponseV1> _decodeVendorCredentialResponse(
  http.Response res,
) async {
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VendorCredentialResponseV1.fromJson(map);
}

Future<VendorMutationResponseV1> _decodeVendorCredentialMutationResponse(
  http.Response res,
) async {
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VendorMutationResponseV1.fromJson(map);
}

/// `POST /api/v1/settings/vendors/credential` — OpenAPI `storeVendorCredentialV1`.
Future<VendorCredentialResponseV1> postSettingsVendorCredentialV1(
  String accessToken, {
  required String vendorId,
  String? apiKey,
  String? apiSecret,
  String? apiToken,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/credential');
  final body = <String, dynamic>{'vendorId': vendorId};
  if (apiKey != null) body['apiKey'] = apiKey;
  if (apiSecret != null) body['apiSecret'] = apiSecret;
  if (apiToken != null) body['apiToken'] = apiToken;
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  return _decodeVendorCredentialResponse(res);
}

/// `GET /api/v1/settings/vendors/credential/{vendor_id}` — OpenAPI `getVendorCredentialV1`.
Future<VendorCredentialResponseV1> getSettingsVendorCredentialV1(
  String accessToken, {
  required String vendorId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/vendors/credential/$vendorId',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  return _decodeVendorCredentialResponse(res);
}

/// `DELETE /api/v1/settings/vendors/credential/{vendor_id}` — OpenAPI `deleteVendorCredentialV1`.
Future<VendorMutationResponseV1> deleteSettingsVendorCredentialV1(
  String accessToken, {
  required String vendorId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/vendors/credential/$vendorId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  return _decodeVendorCredentialMutationResponse(res);
}
