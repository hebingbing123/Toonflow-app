part of 'index.dart';

/// `GET /api/v1/projects/{project_id}/scripts/{script_legacy_id}/storyboards`.
Future<List<StoryboardRow>> fetchStoryboardsForProjectScript(
  String accessToken,
  String projectId,
  int scriptLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptLegacyId/storyboards',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => StoryboardRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/projects/{project_id}/scripts/{script_legacy_id}/storyboards`.
Future<StoryboardRow> createStoryboardUnderProjectScript(
  String accessToken,
  String projectId,
  int scriptLegacyId, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptLegacyId/storyboards',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(fields ?? <String, dynamic>{}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/storyboards/{storyboard_legacy_id}`.
Future<StoryboardRow> fetchStoryboardByProjectAndLegacyId(
  String accessToken,
  String projectId,
  int storyboardLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/storyboards/$storyboardLegacyId',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}/storyboards/{storyboard_legacy_id}` — keys per OpenAPI `PatchStoryboardBody` only.
Future<StoryboardRow> updateStoryboardByProjectAndLegacyId(
  String accessToken,
  String projectId,
  int storyboardLegacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/storyboards/$storyboardLegacyId',
  );
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `DELETE /api/v1/projects/{project_id}/storyboards/{storyboard_legacy_id}`.
Future<void> deleteStoryboardByProjectAndLegacyId(
  String accessToken,
  String projectId,
  int storyboardLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/storyboards/$storyboardLegacyId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}
