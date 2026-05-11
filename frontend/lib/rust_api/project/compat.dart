import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'overview.dart';
import 'rest.dart';

/// Project compatibility adapters layered over the v1 project REST API.
/// Compat **`getSingleProject`**: lists owned projects and filters by **`numeric_id`** (no HTTP **`/general/*`**).
Future<List<ProjectRow>> postGeneralGetSingleProject(
  String accessToken,
  int numericId,
) async {
  final rows = await fetchAllProjectsPaged(accessToken);
  return rows.where((r) => r.numericId == numericId).toList();
}

String? projectUuidFromCompatBody(Map<String, dynamic> body) {
  final raw = body['projectUuid'];
  if (raw is! String) {
    return null;
  }
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  return value;
}

/// Compat **`updateProject`**: maps camelCase fields to **`PATCH /api/v1/projects/{uuid}`**.
///
/// [body] must include **`id`** (numeric project id) and at least one of **`intro`**,
/// **`type`** (→ **`mode`**), **`artStyle`**, **`videoRatio`**, **`projectType`**
/// (use **`null`** in the map to clear).
Future<String> postGeneralUpdateProject(
  String accessToken,
  Map<String, dynamic> body,
) async {
  final idRaw = body['id'];
  final numericId = idRaw is int
      ? idRaw
      : idRaw is num
      ? idRaw.toInt()
      : int.tryParse('$idRaw');
  if (numericId == null || numericId <= 0) {
    throw RustApiException('invalid id', statusCode: 400);
  }
  final projectId =
      projectUuidFromCompatBody(body) ??
      await projectIdForNumericId(accessToken, numericId);

  final patch = <String, dynamic>{};
  if (body.containsKey('intro')) {
    patch['intro'] = body['intro'];
  }
  if (body.containsKey('type')) {
    patch['mode'] = body['type'];
  }
  if (body.containsKey('artStyle')) {
    patch['art_style'] = body['artStyle'];
  }
  if (body.containsKey('videoRatio')) {
    patch['video_ratio'] = body['videoRatio'];
  }
  if (body.containsKey('projectType')) {
    patch['project_type'] = body['projectType'];
  }
  if (patch.isEmpty) {
    throw RustApiException(
      'expected at least one of intro, type, artStyle, videoRatio, projectType',
      statusCode: 400,
    );
  }

  await updateProjectByProjectId(accessToken, projectId, patch);
  return '修改成功';
}

/// Mirrors prior **`type` vs `mode`** merge: prefer non-empty **`mode`**, else **`type`**.
String _effectiveProjectMode(String sqliteTypeHint, String mode) {
  final m = mode.trim();
  if (m.isNotEmpty) {
    return m;
  }
  return sqliteTypeHint.trim();
}

Future<List<ProjectRow>> fetchAllProjectsPaged(String accessToken) async {
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
    ensureHttpSuccess(res);
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

Future<String> projectIdForNumericId(String accessToken, int numericId) async {
  final rows = await fetchAllProjectsPaged(accessToken);
  for (final r in rows) {
    if (r.numericId == numericId) {
      return r.id;
    }
  }
  throw RustApiException('not found', statusCode: 404);
}

/// Same rows as **`GET /api/v1/projects`** (paged), formerly **`POST /api/v1/project/get-project`**.
Future<List<ProjectRow>> postProjectGetProject(String accessToken) async {
  return fetchAllProjectsPaged(accessToken);
}

/// [numericId] is `app_project` numeric id column. Uses **`DELETE /api/v1/projects/{project_id}`**.
Future<String> postProjectDeleteProject(
  String accessToken,
  int numericId,
) async {
  final id = await projectIdForNumericId(accessToken, numericId);
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

/// [id] is `app_project` numeric id column. Uses **`PATCH /api/v1/projects/{project_id}`**.
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
  final projectId = await projectIdForNumericId(accessToken, id);
  final modeOut = _effectiveProjectMode(type, mode);
  await updateProjectByProjectId(accessToken, projectId, <String, dynamic>{
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
  });
  return '编辑项目成功';
}
