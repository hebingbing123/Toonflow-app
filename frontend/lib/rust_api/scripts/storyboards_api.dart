import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'storyboards_models.dart';

/// Storyboard CRUD endpoints scoped under project scripts.
/// `GET /api/v1/projects/{project_id}/scripts/{script_numeric_id}/storyboards`.
Future<List<StoryboardRow>> fetchStoryboardsForProjectScript(
  String accessToken,
  String projectId,
  int scriptNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId/storyboards',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => StoryboardRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/projects/{project_id}/scripts/{script_numeric_id}/storyboards`.
Future<StoryboardRow> createStoryboardUnderProjectScript(
  String accessToken,
  String projectId,
  int scriptNumericId, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId/storyboards',
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
    throw RustApiException.fromHttpResponse(res);
  }
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpStatus(res, 201);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/storyboards/{storyboard_numeric_id}`.
Future<StoryboardRow> fetchStoryboardByProjectAndNumericId(
  String accessToken,
  String projectId,
  int storyboardNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/storyboards/$storyboardNumericId',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}/storyboards/{storyboard_numeric_id}` — keys per OpenAPI `PatchStoryboardBody` only.
Future<StoryboardRow> updateStoryboardByProjectAndNumericId(
  String accessToken,
  String projectId,
  int storyboardNumericId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/storyboards/$storyboardNumericId',
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
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardRow.fromJson(map);
}

/// `DELETE /api/v1/projects/{project_id}/storyboards/{storyboard_numeric_id}`.
Future<void> deleteStoryboardByProjectAndNumericId(
  String accessToken,
  String projectId,
  int storyboardNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/storyboards/$storyboardNumericId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpStatus(res, 204);
}
