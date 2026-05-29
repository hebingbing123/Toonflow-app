import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'models/corner_scape.dart';

/// `POST /api/v1/projects/{project_id}/assets/corner-scape` — see `listCornerScapeAssetsByProjectIdV1`.
Future<CornerScapeResponse> fetchCornerScapeAssetsByProjectId(
  String accessToken,
  String projectId, {
  List<String>? types,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/corner-scape',
  );
  final body = <String, dynamic>{};
  if (types != null && types.isNotEmpty) {
    body['types'] = types;
  }
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return CornerScapeResponse.fromJson(map);
}
