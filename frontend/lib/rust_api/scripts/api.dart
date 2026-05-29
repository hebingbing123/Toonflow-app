import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'storyboards_models.dart';

/// Script CRUD, export, and extraction endpoints.
/// `POST /api/v1/projects/{project_id}/scripts/get-script-api` — script list + **`relatedAssets`**.
Future<List<ScriptWorkbenchDetailRow>> postScriptsGetScriptApiByProjectId(
  String accessToken,
  String projectId, {
  String? name,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/get-script-api',
  );
  final body = <String, dynamic>{};
  if (name != null && name.isNotEmpty) {
    body['name'] = name;
  }
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => ScriptWorkbenchDetailRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/projects/{project_id}/scripts/batch-add` — batch add scripts under project (UUID path).
Future<BatchAddScriptResponseV1> postScriptsBatchAddByProjectId(
  String accessToken, {
  required String projectId,
  required List<BatchAddScriptItemV1> data,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/batch-add',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'data': data.map((e) => e.toJson()).toList()}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchAddScriptResponseV1.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/scripts/{script_numeric_id}`.
Future<ScriptRow> fetchScriptByProjectAndNumericId(
  String accessToken,
  String projectId,
  int scriptNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ScriptRow.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}/scripts/{script_numeric_id}`.
Future<ScriptRow> updateScriptByProjectAndNumericId(
  String accessToken,
  String projectId,
  int scriptNumericId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId',
  );
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
  return ScriptRow.fromJson(map);
}

/// `DELETE /api/v1/projects/{project_id}/scripts/{script_numeric_id}`.
Future<void> deleteScriptByProjectAndNumericId(
  String accessToken,
  String projectId,
  int scriptNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId',
  );
  final res = await http
      .delete(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpStatus(res, 204);
}

/// `POST /api/v1/projects/{project_id}/scripts` — see `createScriptUnderProjectByProjectIdV1`.
Future<ScriptRow> createScriptUnderProject(
  String accessToken,
  String projectId, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/scripts');
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
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpStatus(res, 201);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ScriptRow.fromJson(map);
}

/// `POST /api/v1/scripts/export` — **`application/zip`** body. See `exportScriptsZipV1`.
Future<Uint8List> exportScriptsZip(
  String accessToken,
  List<int> numericIds,
) async {
  final ids = numericIds.where((id) => id > 0).toList(growable: false);
  if (ids.isEmpty) {
    throw RustApiException(
      'numeric_ids must be non-empty',
      statusCode: 400,
    );
  }
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/export');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'numeric_ids': ids}),
      )
      .timeout(const Duration(seconds: 120));
  ensureHttpSuccess(res);
  return res.bodyBytes;
}

/// `POST /api/v1/scripts/extract-state/poll` — scripts with **`extract_state` ≠ 0**. See `pollScriptExtractStateV1`.
Future<List<ScriptExtractStatePollRow>> pollScriptExtractState(
  String accessToken,
  List<int> numericIds,
) async {
  final ids = numericIds.where((id) => id > 0).toList(growable: false);
  if (ids.isEmpty) {
    return const <ScriptExtractStatePollRow>[];
  }
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/extract-state/poll');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'numeric_ids': ids}),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ScriptExtractStatePollRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/scripts/extract-assets` — background LLM extraction (**503** if LLM/DB unset). See `startScriptAssetExtractV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectNumericId`** is legacy **`numeric_id`**.
Map<String, dynamic> buildScriptAssetExtractBody({
  int? projectNumericId,
  String? projectUuid,
  required List<int> scriptNumericIds,
  int? groupSize,
}) {
  final body = <String, dynamic>{'script_numeric_ids': scriptNumericIds};
  final u = projectUuid?.trim();
  if (u != null && u.isNotEmpty) {
    body['project_uuid'] = u;
  } else if (projectNumericId != null) {
    body['project_numeric_id'] = projectNumericId;
  } else {
    throw ArgumentError('projectUuid or projectNumericId is required');
  }
  if (groupSize != null) {
    body['group_size'] = groupSize;
  }
  return body;
}

Future<ExtractAssetsAcceptedResponse> startScriptAssetExtract(
  String accessToken, {
  int? projectNumericId,
  String? projectUuid,
  required List<int> scriptNumericIds,
  int? groupSize,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/extract-assets');
  final body = buildScriptAssetExtractBody(
    projectNumericId: projectNumericId,
    projectUuid: projectUuid,
    scriptNumericIds: scriptNumericIds,
    groupSize: groupSize,
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ExtractAssetsAcceptedResponse.fromJson(map);
}
