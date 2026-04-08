part of 'index.dart';

/// `GET /api/v1/projects` — projects owned by the JWT subject. See `listProjectsV1`.
Future<List<ProjectRow>> fetchProjects(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectRow.fromJson(map);
}

/// `PATCH /api/v1/projects/legacy/{legacy_id}` — merge patch for `name` / `intro` only.
///
/// [body] must only include keys allowed by OpenAPI `PatchProjectBody` (unknown keys → HTTP 400).
/// See `patchProjectByLegacyIdV1`.
Future<ProjectRow> updateProjectByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
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
  return ProjectRow.fromJson(map);
}

/// `DELETE /api/v1/projects/legacy/{legacy_id}` — see `deleteProjectByLegacyIdV1`.
Future<void> deleteProjectByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId');
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
