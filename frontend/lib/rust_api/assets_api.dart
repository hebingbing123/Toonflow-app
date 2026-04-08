part of 'index.dart';

/// `POST /api/v1/projects/legacy/{project_legacy_id}/assets/corner-scape` — see `listCornerScapeAssetsByLegacyV1`.
Future<CornerScapeResponse> fetchCornerScapeAssetsByLegacyId(
  String accessToken,
  int projectLegacyId, {
  List<String>? types,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/corner-scape',
  );
  final body = <String, dynamic>{};
  if (types != null && types.isNotEmpty) {
    body['types'] = types;
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return CornerScapeResponse.fromJson(map);
}
