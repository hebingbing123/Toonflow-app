part of 'index.dart';

/// `POST /api/v1/general/get-single-project` — legacy **`getSingleProject`**; **`id`** = **`app_project.legacy_id`**.
Future<List<ProjectRow>> postGeneralGetSingleProject(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/general/get-single-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': legacyId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/general/update-project` — legacy **`updateProject`**.
///
/// [body] must include **`id`** (legacy project id) and at least one of **`intro`**,
/// **`type`**, **`artStyle`**, **`videoRatio`**, **`projectType`** (use JSON **`null`** in the map to clear).
Future<String> postGeneralUpdateProject(
  String accessToken,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/general/update-project');
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// Mirrors legacy **`type` vs `mode`** merge: prefer non-empty **`mode`**, else **`type`**.
String _effectiveProjectMode(String legacySqliteType, String mode) {
  final m = mode.trim();
  if (m.isNotEmpty) {
    return m;
  }
  return legacySqliteType.trim();
}

Future<List<ProjectRow>> _fetchAllProjectsPaged(String accessToken) async {
  final out = <ProjectRow>[];
  var offset = 0;
  const page = 100;
  while (true) {
    final uri = Uri.parse(
      '$kApiBaseUrl/api/v1/projects?limit=$page&offset=$offset',
    );
    final res = await http
        .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw RustApiException(res.body, statusCode: res.statusCode);
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    final batch = list
        .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
        .toList();
    out.addAll(batch);
    if (batch.length < page) {
      break;
    }
    offset += page;
    if (offset > 100000) {
      break;
    }
  }
  return out;
}

Future<String> _projectIdForLegacyId(
  String accessToken,
  int legacyId,
) async {
  final rows = await _fetchAllProjectsPaged(accessToken);
  for (final r in rows) {
    if (r.legacyId == legacyId) {
      return r.id;
    }
  }
  throw RustApiException('not found', statusCode: 404);
}

/// Same rows as **`GET /api/v1/projects`** (paged), formerly **`POST /api/v1/project/get-project`**.
Future<List<ProjectRow>> postProjectGetProject(String accessToken) async {
  return _fetchAllProjectsPaged(accessToken);
}

/// [legacyId] is `app_project.legacy_id`. Uses **`DELETE /api/v1/projects/{project_id}`**.
Future<String> postProjectDeleteProject(
  String accessToken,
  int legacyId,
) async {
  final id = await _projectIdForLegacyId(accessToken, legacyId);
  await deleteProjectByProjectId(accessToken, id);
  return '删除项目成功';
}

/// All fields required (may be empty strings). Uses **`POST /api/v1/projects`**.
Future<String> postProjectAddProject(
  String accessToken, {
  required String projectType,
  required String name,
  required String intro,
  required String type,
  required String artStyle,
  required String directorManual,
  required String videoRatio,
  required String imageModel,
  required String videoModel,
  required String imageQuality,
  required String mode,
}) async {
  final modeOut = _effectiveProjectMode(type, mode);
  final fields = <String, dynamic>{
    'name': name,
    'intro': intro,
    'project_type': projectType,
    'art_style': artStyle,
    'director_manual': directorManual,
    'video_ratio': videoRatio,
    'image_model': imageModel,
    'video_model': videoModel,
    'image_quality': imageQuality,
  };
  if (modeOut.isNotEmpty) {
    fields['mode'] = modeOut;
  }
  await createProject(accessToken, fields: fields);
  return '新增项目成功';
}

/// [id] is `app_project.legacy_id`. Uses **`PATCH /api/v1/projects/{project_id}`**.
Future<String> postProjectEditProject(
  String accessToken, {
  required int id,
  required String name,
  required String intro,
  required String type,
  required String artStyle,
  required String directorManual,
  required String videoRatio,
  required String imageModel,
  required String videoModel,
  required String imageQuality,
  required String projectType,
  required String mode,
}) async {
  final projectId = await _projectIdForLegacyId(accessToken, id);
  final modeOut = _effectiveProjectMode(type, mode);
  await updateProjectByProjectId(
    accessToken,
    projectId,
    <String, dynamic>{
      'name': name,
      'intro': intro,
      'project_type': projectType,
      'art_style': artStyle,
      'director_manual': directorManual,
      'video_ratio': videoRatio,
      'image_model': imageModel,
      'video_model': videoModel,
      'image_quality': imageQuality,
      'mode': modeOut,
    },
  );
  return '编辑项目成功';
}
