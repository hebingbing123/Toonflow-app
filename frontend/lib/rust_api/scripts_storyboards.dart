part of 'index.dart';

class ScriptRow {
  const ScriptRow({
    required this.id,
    required this.projectId,
    required this.legacyId,
    this.name,
    this.content,
    this.extractState,
    this.createTimeMs,
  });

  final String id;
  final String projectId;
  final int legacyId;
  final String? name;
  final String? content;
  final int? extractState;
  final int? createTimeMs;

  factory ScriptRow.fromJson(Map<String, dynamic> json) {
    return ScriptRow(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String?,
      content: json['content'] as String?,
      extractState: json['extract_state'] == null
          ? null
          : (json['extract_state'] as num).toInt(),
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// Linked asset brief on **`POST /api/v1/scripts/get-script-api`** — JSON **`id`** = **`app_asset.legacy_id`**.
class LegacyScriptRelatedAssetBrief {
  const LegacyScriptRelatedAssetBrief({
    required this.legacyId,
    required this.name,
  });

  final int legacyId;
  final String name;

  factory LegacyScriptRelatedAssetBrief.fromJson(Map<String, dynamic> json) {
    return LegacyScriptRelatedAssetBrief(
      legacyId: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}

/// One script row from **`POST /api/v1/scripts/get-script-api`** (camelCase **`extractState`**, **`relatedAssets`**, …).
class LegacyScriptsGetScriptApiItem {
  const LegacyScriptsGetScriptApiItem({
    required this.legacyId,
    this.name,
    this.content,
    this.extractState,
    this.errorReason,
    this.createTime,
    required this.relatedAssets,
  });

  final int legacyId;
  final String? name;
  final String? content;
  final int? extractState;
  final String? errorReason;
  final int? createTime;
  final List<LegacyScriptRelatedAssetBrief> relatedAssets;

  factory LegacyScriptsGetScriptApiItem.fromJson(Map<String, dynamic> json) {
    final raw = json['relatedAssets'] as List<dynamic>? ?? [];
    return LegacyScriptsGetScriptApiItem(
      legacyId: (json['id'] as num).toInt(),
      name: json['name'] as String?,
      content: json['content'] as String?,
      extractState: json['extractState'] == null
          ? null
          : (json['extractState'] as num).toInt(),
      errorReason: json['errorReason'] as String?,
      createTime: json['createTime'] == null
          ? null
          : (json['createTime'] as num).toInt(),
      relatedAssets: raw
          .map(
            (e) => LegacyScriptRelatedAssetBrief.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

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

/// Row from **`POST /api/v1/scripts/extract-state/poll`** — OpenAPI **`ScriptExtractStatePollRow`**.
class ScriptExtractStatePollRow {
  const ScriptExtractStatePollRow({
    required this.legacyId,
    this.extractState,
    this.errorReason,
  });

  final int legacyId;
  final int? extractState;
  final String? errorReason;

  factory ScriptExtractStatePollRow.fromJson(Map<String, dynamic> json) {
    return ScriptExtractStatePollRow(
      legacyId: (json['legacy_id'] as num).toInt(),
      extractState: json['extract_state'] == null
          ? null
          : (json['extract_state'] as num).toInt(),
      errorReason: json['error_reason'] as String?,
    );
  }
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

/// `POST /api/v1/scripts/extract-assets` — OpenAPI **`ExtractAssetsAcceptedResponse`** (async job).
class ExtractAssetsAcceptedResponse {
  const ExtractAssetsAcceptedResponse({
    required this.status,
    required this.message,
  });

  final String status;
  final String message;

  factory ExtractAssetsAcceptedResponse.fromJson(Map<String, dynamic> json) {
    return ExtractAssetsAcceptedResponse(
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }
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

class StoryboardRow {
  const StoryboardRow({
    required this.id,
    required this.scriptId,
    required this.legacyId,
    this.legacyScriptId,
    this.prompt,
    this.filePath,
    this.duration,
    this.state,
    this.trackId,
    this.reason,
    this.track,
    this.videoDesc,
    this.shouldGenerateImage,
    this.legacyProjectId,
    this.flowId,
    this.sbIndex,
    this.createTimeMs,
  });

  final String id;
  final String scriptId;
  final int legacyId;
  final int? legacyScriptId;
  final String? prompt;
  final String? filePath;
  final String? duration;
  final String? state;
  final int? trackId;
  final String? reason;
  final String? track;
  final String? videoDesc;
  final int? shouldGenerateImage;
  final int? legacyProjectId;
  final int? flowId;
  final int? sbIndex;
  final int? createTimeMs;

  factory StoryboardRow.fromJson(Map<String, dynamic> json) {
    int? ni(String k) => json[k] == null ? null : (json[k] as num).toInt();
    return StoryboardRow(
      id: json['id'] as String,
      scriptId: json['script_id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      legacyScriptId: ni('legacy_script_id'),
      prompt: json['prompt'] as String?,
      filePath: json['file_path'] as String?,
      duration: json['duration'] as String?,
      state: json['state'] as String?,
      trackId: ni('track_id'),
      reason: json['reason'] as String?,
      track: json['track'] as String?,
      videoDesc: json['video_desc'] as String?,
      shouldGenerateImage: ni('should_generate_image'),
      legacyProjectId: ni('legacy_project_id'),
      flowId: ni('flow_id'),
      sbIndex: ni('sb_index'),
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/scripts/legacy/{script_legacy_id}/storyboards`. See `listStoryboardsByScriptLegacyIdV1`.
Future<List<StoryboardRow>> fetchStoryboardsForScript(
  String accessToken,
  int scriptLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/scripts/legacy/$scriptLegacyId/storyboards',
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

/// `POST /api/v1/scripts/legacy/{script_legacy_id}/storyboards` — see `createStoryboardUnderScriptLegacyV1`.
Future<StoryboardRow> createStoryboardUnderScriptLegacy(
  String accessToken,
  int scriptLegacyId, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/scripts/legacy/$scriptLegacyId/storyboards',
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

/// `GET /api/v1/storyboards/legacy/{legacy_id}`. See `getStoryboardByLegacyIdV1`.
Future<StoryboardRow> fetchStoryboardByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/storyboards/legacy/$legacyId');
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

/// `PATCH /api/v1/storyboards/legacy/{legacy_id}` — keys per OpenAPI `PatchStoryboardBody` only.
///
/// Unknown keys → HTTP 400. See `patchStoryboardByLegacyIdV1`.
Future<StoryboardRow> updateStoryboardByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/storyboards/legacy/$legacyId');
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

/// `DELETE /api/v1/storyboards/legacy/{legacy_id}` — see `deleteStoryboardByLegacyIdV1`.
Future<void> deleteStoryboardByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/storyboards/legacy/$legacyId');
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
