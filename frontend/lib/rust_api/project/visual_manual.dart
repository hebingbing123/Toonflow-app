part of '../index.dart';

/// Visual manual fetch endpoints grouped under the project creative-manual subdomain.
/// `GET /api/v1/visual-manual` — OpenAPI `getVisualManualV1`.
Future<VisualManualResponseV1> fetchVisualManualV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}

/// `POST /api/v1/visual-manual` — OpenAPI `postVisualManualV1` (same JSON as GET; body ignored).
Future<VisualManualResponseV1> fetchVisualManualPostV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}
