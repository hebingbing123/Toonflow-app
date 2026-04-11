part of 'index.dart';

/// `POST /api/v1/projects/{project_id}/scripts/get-script-api` — script list + **`relatedAssets`**.
Future<List<LegacyScriptsGetScriptApiItem>> postScriptsGetScriptApiByProjectId(
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map(
        (e) =>
            LegacyScriptsGetScriptApiItem.fromJson(e as Map<String, dynamic>),
      )
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': data.map((e) => e.toJson()).toList(),
        }),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchAddScriptResponseV1.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/scripts/{script_numeric_id}`.
Future<ScriptRow> fetchScriptByProjectAndLegacyId(
  String accessToken,
  String projectId,
  int scriptNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId',
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
  return ScriptRow.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}/scripts/{script_numeric_id}`.
Future<ScriptRow> updateScriptByProjectAndLegacyId(
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
  return ScriptRow.fromJson(map);
}

/// `DELETE /api/v1/projects/{project_id}/scripts/{script_numeric_id}`.
Future<void> deleteScriptByProjectAndLegacyId(
  String accessToken,
  String projectId,
  int scriptNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId',
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
  return ScriptRow.fromJson(map);
}

/// `POST /api/v1/scripts/export` — **`application/zip`** body. See `exportScriptsZipV1`.
Future<Uint8List> exportScriptsZip(
  String accessToken,
  List<int> numericIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/export');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'numeric_ids': numericIds}),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return res.bodyBytes;
}

/// `POST /api/v1/scripts/extract-state/poll` — scripts with **`extract_state` ≠ 0**. See `pollScriptExtractStateV1`.
Future<List<ScriptExtractStatePollRow>> pollScriptExtractState(
  String accessToken,
  List<int> numericIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/extract-state/poll');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'numeric_ids': numericIds}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ScriptExtractStatePollRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/scripts/extract-assets` — background LLM extraction (**503** if LLM/DB unset). See `startScriptAssetExtractV1`.
Future<ExtractAssetsAcceptedResponse> startScriptAssetExtract(
  String accessToken, {
  required int projectNumericId,
  required List<int> scriptNumericIds,
  int? groupSize,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/extract-assets');
  final body = <String, dynamic>{
    'project_numeric_id': projectNumericId,
    'script_numeric_ids': scriptNumericIds,
  };
  if (groupSize != null) {
    body['group_size'] = groupSize;
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ExtractAssetsAcceptedResponse.fromJson(map);
}
