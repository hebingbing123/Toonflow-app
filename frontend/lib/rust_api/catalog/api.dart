import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import '../shared_kernel/index.dart';

/// Model and vendor catalog query endpoints.
/// `GET /api/v1/models?type=…` — Bearer; see `listModelsV1`.
Future<List<ModelListEntry>> fetchModelsCatalog(
  String accessToken, {
  String typeFilter = 'all',
  bool includePricing = false,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models').replace(
    queryParameters: <String, String>{
      'type': typeFilter,
      if (includePricing) 'include_pricing': 'true',
    },
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ModelListEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/settings/vendors/summary` — OpenAPI `getSettingsVendorsSummaryV1`.
Future<VendorsSummaryResponseV1> fetchVendorsSummaryV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VendorsSummaryResponseV1.fromJson(map);
}

/// `GET /api/v1/models/detail?model_id=…` — Bearer; see `modelDetailV1`.
Future<ModelDetailResponse> fetchModelDetail(
  String accessToken, {
  required String modelId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/models/detail',
  ).replace(queryParameters: {'model_id': modelId});
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ModelDetailResponse.fromJson(map);
}

/// `GET /api/v1/models/text-default` — OpenAPI `getTextModelDefaultV1`.
Future<TextModelDefaultV1> fetchTextModelDefaultV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models/text-default');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return TextModelDefaultV1.fromJson(map);
}

/// `PATCH /api/v1/models/text-default` — set per-user text model preference; pass `null` to reset.
Future<TextModelDefaultV1> patchTextModelDefaultV1(
  String accessToken, {
  String? modelId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models/text-default');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'model_id': modelId}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return TextModelDefaultV1.fromJson(map);
}
