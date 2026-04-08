part of 'index.dart';

/// `POST /api/v1/scripts/get-script-api` — legacy **`getScrptApi`** list + **`relatedAssets`**.
Future<List<LegacyScriptsGetScriptApiItem>> postScriptsGetScriptApi(
  String accessToken,
  int projectId, {
  String? name,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/get-script-api');
  final body = <String, dynamic>{'projectId': projectId};
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

/// `GET /api/v1/scripts/legacy/{legacy_id}`. See `getScriptByLegacyIdV1`.
Future<ScriptRow> fetchScriptByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/legacy/$legacyId');
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

/// `PATCH /api/v1/scripts/legacy/{legacy_id}` — only `name`, `content`, `extract_state`.
///
/// Unknown keys → HTTP 400. See `patchScriptByLegacyIdV1`.
Future<ScriptRow> updateScriptByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/legacy/$legacyId');
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

/// `POST /api/v1/projects/legacy/{project_legacy_id}/scripts` — see `createScriptUnderProjectLegacyV1`.
Future<ScriptRow> createScriptUnderProjectLegacy(
  String accessToken,
  int projectLegacyId, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/scripts',
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
  return ScriptRow.fromJson(map);
}

/// `DELETE /api/v1/scripts/legacy/{legacy_id}` — see `deleteScriptByLegacyIdV1`.
Future<void> deleteScriptByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/legacy/$legacyId');
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

/// `POST /api/v1/scripts/export` — **`application/zip`** body. See `exportScriptsZipV1`.
Future<Uint8List> exportScriptsZip(
  String accessToken,
  List<int> legacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/export');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'legacy_ids': legacyIds}),
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
  List<int> legacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/extract-state/poll');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'legacy_ids': legacyIds}),
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
  required int projectLegacyId,
  required List<int> scriptLegacyIds,
  int? groupSize,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/extract-assets');
  final body = <String, dynamic>{
    'project_legacy_id': projectLegacyId,
    'script_legacy_ids': scriptLegacyIds,
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
