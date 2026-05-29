import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'overview.dart';

const _unsetProjectStyleConfigField = Object();

Map<String, dynamic> buildProjectStyleConfigPatchBody({
  Object? artStylePack = _unsetProjectStyleConfigField,
  Object? storyStylePack = _unsetProjectStyleConfigField,
}) {
  final body = <String, dynamic>{};
  if (!identical(artStylePack, _unsetProjectStyleConfigField)) {
    body['artStylePack'] = artStylePack;
  }
  if (!identical(storyStylePack, _unsetProjectStyleConfigField)) {
    body['storyStylePack'] = storyStylePack;
  }
  return body;
}

/// Primary project REST endpoints and summary payloads.
/// `GET /api/v1/projects` — projects visible in the caller's current workspace scope.
Future<List<ProjectRow>> fetchProjects(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

class ProjectsSummary {
  const ProjectsSummary({
    required this.projectCount,
    required this.scriptCount,
    required this.storyboardCount,
    required this.novelCount,
    required this.roleCount,
    required this.artStyleCount,
    required this.assetCount,
    required this.videoCount,
  });

  final int projectCount;
  final int scriptCount;
  final int storyboardCount;
  final int novelCount;
  final int roleCount;
  final int artStyleCount;
  final int assetCount;
  final int videoCount;

  factory ProjectsSummary.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num).toInt();
    return ProjectsSummary(
      projectCount: n('project_count'),
      scriptCount: n('script_count'),
      storyboardCount: n('storyboard_count'),
      novelCount: json['novel_count'] != null
          ? (json['novel_count'] as num).toInt()
          : 0,
      roleCount: json['role_count'] != null
          ? (json['role_count'] as num).toInt()
          : 0,
      artStyleCount: json['art_style_count'] != null
          ? (json['art_style_count'] as num).toInt()
          : 0,
      assetCount: json['asset_count'] != null
          ? (json['asset_count'] as num).toInt()
          : 0,
      videoCount: json['video_count'] != null
          ? (json['video_count'] as num).toInt()
          : 0,
    );
  }
}

/// `GET /api/v1/projects/summary` — totals for the caller. See `getProjectsSummaryV1`.
Future<ProjectsSummary> fetchProjectsSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/summary');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectsSummary.fromJson(map);
}

/// `POST /api/v1/projects` — optional snake_case fields; see `createProjectV1`.
Future<ProjectRow> createProject(
  String accessToken, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(fields ?? <String, dynamic>{}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpStatus(res, 201);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectRow.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}` — merge patch; see `patchProjectByProjectIdV1`.
///
/// [body] must only include keys allowed by OpenAPI `PatchProjectBody` (unknown keys → HTTP 400).
Future<ProjectRow> updateProjectByProjectId(
  String accessToken,
  String projectId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId');
  final res = await http
      .patch(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectRow.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}/style-config` — update style-pack selections.
Future<ProjectRow> patchProjectStyleConfigByProjectId(
  String accessToken,
  String projectId, {
  Object? artStylePack = _unsetProjectStyleConfigField,
  Object? storyStylePack = _unsetProjectStyleConfigField,
}) async {
  final body = buildProjectStyleConfigPatchBody(
    artStylePack: artStylePack,
    storyStylePack: storyStylePack,
  );
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/style-config');
  final res = await http
      .patch(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectRow.fromJson(map);
}

/// `DELETE /api/v1/projects/{project_id}` — see `deleteProjectByProjectIdV1`.
Future<void> deleteProjectByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId');
  final res = await http
      .delete(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpStatus(res, 204);
}
