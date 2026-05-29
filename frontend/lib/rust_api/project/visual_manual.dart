import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import '../shared_kernel/index.dart';

/// Visual manual fetch endpoints grouped under the project creative-manual subdomain.
/// `GET /api/v1/visual-manual` — OpenAPI `getVisualManualV1`.
Future<VisualManualResponseV1> fetchVisualManualV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 120));
  ensureHttpSuccess(res);
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
        headers: rustApiJsonAuthHeaders(accessToken),
        body: '{}',
      )
      .timeout(const Duration(seconds: 120));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}
