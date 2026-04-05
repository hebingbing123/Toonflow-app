import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Thrown when the Rust API returns a non-2xx or the body cannot be parsed.
class RustApiException implements Exception {
  RustApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'RustApiException($statusCode): $message';
}

class ProjectRow {
  const ProjectRow({
    required this.id,
    required this.legacyId,
    this.name,
    this.intro,
    this.projectType,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final String? name;
  final String? intro;
  final String? projectType;
  final int? createTimeMs;

  factory ProjectRow.fromJson(Map<String, dynamic> json) {
    return ProjectRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String?,
      intro: json['intro'] as String?,
      projectType: json['project_type'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

class ScriptBrief {
  const ScriptBrief({
    required this.legacyId,
    this.name,
    this.extractState,
  });

  final int legacyId;
  final String? name;
  final int? extractState;

  factory ScriptBrief.fromJson(Map<String, dynamic> json) {
    return ScriptBrief(
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String?,
      extractState: json['extract_state'] == null
          ? null
          : (json['extract_state'] as num).toInt(),
    );
  }
}

class ProjectDetail {
  const ProjectDetail({
    required this.project,
    required this.scripts,
  });

  final ProjectRow project;
  final List<ScriptBrief> scripts;

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    return ProjectDetail(
      project: ProjectRow.fromJson(json['project'] as Map<String, dynamic>),
      scripts: (json['scripts'] as List<dynamic>)
          .map((e) => ScriptBrief.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProjectStats {
  const ProjectStats({
    required this.scriptCount,
    required this.storyboardCount,
    required this.roleCount,
    required this.videoCount,
  });

  final int scriptCount;
  final int storyboardCount;
  final int roleCount;
  final int videoCount;

  factory ProjectStats.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num).toInt();
    return ProjectStats(
      scriptCount: n('script_count'),
      storyboardCount: n('storyboard_count'),
      roleCount: n('role_count'),
      videoCount: n('video_count'),
    );
  }
}

/// JSON body for **`GET /health`** and **`GET /api/v1/health`** (OpenAPI `HealthResponse`).
class HealthResponse {
  const HealthResponse({
    required this.status,
    required this.service,
  });

  final String status;
  final String service;

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String,
      service: json['service'] as String,
    );
  }
}

/// `GET /api/v1/health` — no auth.
Future<HealthResponse> fetchHealthV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/health');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HealthResponse.fromJson(map);
}

/// Unversioned **`GET /health`** — same JSON as [fetchHealthV1].
Future<HealthResponse> fetchHealthRoot() async {
  final uri = Uri.parse('$kApiBaseUrl/health');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HealthResponse.fromJson(map);
}

/// `GET /api/v1/version` — no auth; OpenAPI `VersionResponse`.
class VersionResponse {
  const VersionResponse({
    required this.service,
    required this.version,
    this.gitSha,
  });

  final String service;
  final String version;
  final String? gitSha;

  factory VersionResponse.fromJson(Map<String, dynamic> json) {
    return VersionResponse(
      service: json['service'] as String,
      version: json['version'] as String,
      gitSha: json['git_sha'] as String?,
    );
  }
}

Future<VersionResponse> fetchVersionV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/version');
  final res = await http.get(uri).timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VersionResponse.fromJson(map);
}

/// `GET /api/v1/ready` — no auth; see `readyV1`.
class ReadyV1Response {
  const ReadyV1Response({
    required this.status,
    required this.database,
  });

  final String status;
  final String database;

  factory ReadyV1Response.fromJson(Map<String, dynamic> json) {
    return ReadyV1Response(
      status: json['status'] as String,
      database: json['database'] as String,
    );
  }
}

Future<ReadyV1Response> fetchReadyV1() async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/ready');
  final res = await http.get(uri).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ReadyV1Response.fromJson(map);
}

/// `GET /api/v1/me` — Bearer; see `meV1` / OpenAPI `MeResponse`.
class MeResponse {
  const MeResponse({
    required this.sub,
    this.email,
    required this.planTier,
    this.billingCurrency,
    this.billingProvider,
  });

  final String sub;
  final String? email;
  final String planTier;
  final String? billingCurrency;
  final String? billingProvider;

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      sub: json['sub'] as String,
      email: json['email'] as String?,
      planTier: json['plan_tier'] as String,
      billingCurrency: json['billing_currency'] as String?,
      billingProvider: json['billing_provider'] as String?,
    );
  }
}

Future<MeResponse> fetchMeV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/me');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MeResponse.fromJson(map);
}

/// `GET /api/v1/usage/summary` — OpenAPI `UsageSummaryResponse`.
class UsageSummaryResponse {
  const UsageSummaryResponse({
    required this.eventsLast24h,
    required this.eventsLast7d,
    required this.eventCountsLast7d,
  });

  final int eventsLast24h;
  final int eventsLast7d;
  final Map<String, int> eventCountsLast7d;

  factory UsageSummaryResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['event_counts_last_7d'];
    final counts = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is num) {
          counts[k] = v.toInt();
        }
      });
    }
    return UsageSummaryResponse(
      eventsLast24h: (json['events_last_24h'] as num).toInt(),
      eventsLast7d: (json['events_last_7d'] as num).toInt(),
      eventCountsLast7d: counts,
    );
  }
}

/// `GET /api/v1/usage/summary` — see `usageSummaryV1`.
Future<UsageSummaryResponse> fetchUsageSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/usage/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UsageSummaryResponse.fromJson(map);
}

/// Row from `GET /api/v1/models` — OpenAPI `ModelListEntry`.
class ModelListEntry {
  const ModelListEntry({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
    required this.name,
  });

  final int id;
  final String label;
  final String value;
  final String type;
  final String name;

  factory ModelListEntry.fromJson(Map<String, dynamic> json) {
    return ModelListEntry(
      id: (json['id'] as num).toInt(),
      label: json['label'] as String,
      value: json['value'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
    );
  }
}

/// `GET /api/v1/models/detail` body — OpenAPI `ModelDetailResponse`.
class ModelDetailResponse {
  const ModelDetailResponse({
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.modelName,
    required this.type,
  });

  final int vendorId;
  final String vendorName;
  final String name;
  final String modelName;
  final String type;

  factory ModelDetailResponse.fromJson(Map<String, dynamic> json) {
    return ModelDetailResponse(
      vendorId: (json['vendor_id'] as num).toInt(),
      vendorName: json['vendor_name'] as String,
      name: json['name'] as String,
      modelName: json['model_name'] as String,
      type: json['type'] as String,
    );
  }
}

/// `GET /api/v1/models?type=…` — Bearer; see `listModelsV1`.
Future<List<ModelListEntry>> fetchModelsCatalog(
  String accessToken, {
  String typeFilter = 'all',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models').replace(
    queryParameters: {'type': typeFilter},
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ModelListEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/models/detail?model_id=…` — Bearer; see `modelDetailV1`.
Future<ModelDetailResponse> fetchModelDetail(
  String accessToken, {
  required String modelId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/models/detail').replace(
    queryParameters: {'model_id': modelId},
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ModelDetailResponse.fromJson(map);
}

/// `POST /api/v1/agents/memory/query` — camelCase body; see `queryAgentMemoryV1`.
Future<List<dynamic>> queryAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/query');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'episodesId': episodesId,
  };
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return jsonDecode(res.body) as List<dynamic>;
}

/// `GET /api/v1/projects` — projects owned by the JWT subject. See `listProjectsV1`.
Future<List<ProjectRow>> fetchProjects(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
    required this.assetCount,
  });

  final int projectCount;
  final int scriptCount;
  final int storyboardCount;
  final int assetCount;

  factory ProjectsSummary.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num).toInt();
    return ProjectsSummary(
      projectCount: n('project_count'),
      scriptCount: n('script_count'),
      storyboardCount: n('storyboard_count'),
      assetCount: json['asset_count'] != null
          ? (json['asset_count'] as num).toInt()
          : 0,
    );
  }
}

/// `GET /api/v1/projects/summary` — totals for the caller. See `getProjectsSummaryV1`.
Future<ProjectsSummary> fetchProjectsSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

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

/// `GET /api/v1/scripts/legacy/{legacy_id}`. See `getScriptByLegacyIdV1`.
Future<ScriptRow> fetchScriptByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/scripts/legacy/$legacyId');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
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
Future<void> deleteStoryboardByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/storyboards/legacy/$legacyId');
  final res = await http
      .delete(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

class SkillFileMeta {
  const SkillFileMeta({
    required this.path,
    required this.sizeBytes,
  });

  final String path;
  final int sizeBytes;

  factory SkillFileMeta.fromJson(Map<String, dynamic> json) {
    return SkillFileMeta(
      path: json['path'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/skills/summary`. See `getSkillsSummaryV1`.
class SkillsSummary {
  const SkillsSummary({
    required this.markdownFileCount,
    required this.totalBytes,
  });

  final int markdownFileCount;
  final int totalBytes;

  factory SkillsSummary.fromJson(Map<String, dynamic> json) {
    return SkillsSummary(
      markdownFileCount: (json['markdown_file_count'] as num).toInt(),
      totalBytes: (json['total_bytes'] as num).toInt(),
    );
  }
}

class SkillContentResponse {
  const SkillContentResponse({
    required this.path,
    required this.content,
  });

  final String path;
  final String content;

  factory SkillContentResponse.fromJson(Map<String, dynamic> json) {
    return SkillContentResponse(
      path: json['path'] as String,
      content: json['content'] as String,
    );
  }
}

class HarnessToolInfo {
  const HarnessToolInfo({required this.name, required this.description});

  final String name;
  final String description;

  factory HarnessToolInfo.fromJson(Map<String, dynamic> json) {
    return HarnessToolInfo(
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }
}

class HarnessToolsResponse {
  const HarnessToolsResponse({required this.tools});

  final List<HarnessToolInfo> tools;

  factory HarnessToolsResponse.fromJson(Map<String, dynamic> json) {
    return HarnessToolsResponse(
      tools: (json['tools'] as List<dynamic>)
          .map((e) => HarnessToolInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class JobRow {
  const JobRow({
    required this.id,
    required this.ownerUserId,
    required this.kind,
    required this.status,
    required this.payload,
    this.result,
    this.errorMessage,
    this.idempotencyKey,
    this.claimedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String kind;
  final String status;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? result;
  final String? errorMessage;
  final String? idempotencyKey;
  /// Worker label when `running` (`WORKER_ID` on server); mirrors OpenAPI `claimed_by`.
  final String? claimedBy;
  final String createdAt;
  final String updatedAt;

  factory JobRow.fromJson(Map<String, dynamic> json) {
    return JobRow(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      kind: json['kind'] as String,
      status: json['status'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      result: json['result'] == null
          ? null
          : Map<String, dynamic>.from(json['result'] as Map),
      errorMessage: json['error_message'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
      claimedBy: json['claimed_by'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}

/// `GET /api/v1/jobs` — up to 100 jobs for the caller, newest first. See `listJobsV1`.
///
/// [kind] and [status] are optional exact-match query filters (non-empty only).
Future<List<JobRow>> fetchJobs(
  String accessToken, {
  String? kind,
  String? status,
}) async {
  final qp = <String, String>{};
  if (kind != null && kind.trim().isNotEmpty) {
    qp['kind'] = kind.trim();
  }
  if (status != null && status.trim().isNotEmpty) {
    qp['status'] = status.trim();
  }
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs').replace(
    queryParameters: qp.isEmpty ? null : qp,
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/jobs/kinds` — distinct kinds for the caller. See `listJobKindsV1`.
Future<List<String>> fetchJobKinds(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/kinds');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list.map((e) => e as String).toList();
}

class JobKindSummary {
  const JobKindSummary({required this.kind, required this.jobCount});

  final String kind;
  final int jobCount;

  factory JobKindSummary.fromJson(Map<String, dynamic> json) {
    return JobKindSummary(
      kind: json['kind'] as String,
      jobCount: (json['job_count'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/jobs/kinds/summary` — per-kind counts. See `listJobKindSummariesV1`.
Future<List<JobKindSummary>> fetchJobKindSummaries(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/kinds/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => JobKindSummary.fromJson(e as Map<String, dynamic>))
      .toList();
}

class JobStatusSummary {
  const JobStatusSummary({required this.status, required this.jobCount});

  final String status;
  final int jobCount;

  factory JobStatusSummary.fromJson(Map<String, dynamic> json) {
    return JobStatusSummary(
      status: json['status'] as String,
      jobCount: (json['job_count'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/jobs/status/summary` — per-status counts. See `listJobStatusSummariesV1`.
Future<List<JobStatusSummary>> fetchJobStatusSummaries(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/status/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => JobStatusSummary.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/jobs/{id}` — job must belong to the caller. See `getJobV1`.
Future<JobRow> fetchJob(String accessToken, String jobId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/$jobId');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}

/// `POST /api/v1/jobs` — queues a generation job.
///
/// [idempotencyKey]: sent as HTTP header `Idempotency-Key` (server trims and keeps up to
/// 200 characters). Same authenticated user + same key replays return the **existing**
/// job row (HTTP 200), no duplicate insert. See OpenAPI `createJobV1`.
Future<JobRow> createJob(
  String accessToken,
  String kind, {
  Map<String, dynamic> payload = const {},
  String? idempotencyKey,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs');
  final headers = <String, String>{
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };
  if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
    headers['Idempotency-Key'] = idempotencyKey;
  }
  final res = await http
      .post(
        uri,
        headers: headers,
        body: jsonEncode({'kind': kind, 'payload': payload}),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}

/// `POST /api/v1/jobs/{id}/cancel` — `queued` or `running` only. See `cancelJobV1`.
Future<JobRow> cancelJob(String accessToken, String jobId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/$jobId/cancel');
  final res = await http
      .post(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 409) {
    throw RustApiException(res.body, statusCode: 409);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}

/// `POST /api/v1/jobs/{id}/retry` — `failed` jobs re-queued. See `retryJobV1`.
Future<JobRow> retryJob(String accessToken, String jobId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/$jobId/retry');
  final res = await http
      .post(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 409) {
    throw RustApiException(res.body, statusCode: 409);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}

/// `GET /api/v1/skills/summary`. See `getSkillsSummaryV1`.
Future<SkillsSummary> fetchSkillsSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/summary');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillsSummary.fromJson(map);
}

/// `GET /api/v1/skills` — Markdown paths under `data/skills`. See `listSkillsV1`.
Future<List<SkillFileMeta>> fetchSkills(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => SkillFileMeta.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/skills/content?path=…`. See `getSkillContentV1`.
Future<SkillContentResponse> fetchSkillContent(
  String accessToken,
  String relativePath,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content').replace(
    queryParameters: {'path': relativePath},
  );
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillContentResponse.fromJson(map);
}

/// `GET /api/v1/harness/tools`. See `listHarnessToolsV1`.
Future<HarnessToolsResponse> fetchHarnessTools(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/harness/tools');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HarnessToolsResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{legacy_id}` — project plus script briefs. See `getProjectByLegacyIdV1`.
Future<ProjectDetail> fetchProjectByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectDetail.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{legacy_id}/stats` — see `getProjectStatsByLegacyIdV1`.
Future<ProjectStats> fetchProjectStatsByLegacyId(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId/stats');
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectStats.fromJson(map);
}

/// Row from **`GET …/projects/legacy/{id}/assets`** — OpenAPI **`AssetRow`**.
class AssetRow {
  const AssetRow({
    required this.id,
    required this.legacyId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;

  factory AssetRow.fromJson(Map<String, dynamic> json) {
    return AssetRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// Body of **`GET …/assets`** — OpenAPI **`ListAssetsResponse`**.
class ListAssetsResponse {
  const ListAssetsResponse({
    required this.items,
    required this.total,
  });

  final List<AssetRow> items;
  final int total;

  factory ListAssetsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetsResponse(
      items: raw
          .map((e) => AssetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets` — see `listProjectAssetsByLegacyV1`.
Future<ListAssetsResponse> fetchProjectAssetsByLegacyId(
  String accessToken,
  int projectLegacyId, {
  int? scriptLegacyId,
  String? assetType,
  String? name,
  int? page,
  int? limit,
}) async {
  final qp = <String, String>{};
  if (scriptLegacyId != null) {
    qp['script_legacy_id'] = '$scriptLegacyId';
  }
  if (assetType != null && assetType.isNotEmpty) {
    qp['asset_type'] = assetType;
  }
  if (name != null && name.isNotEmpty) {
    qp['name'] = name;
  }
  if (page != null) {
    qp['page'] = '$page';
  }
  if (limit != null) {
    qp['limit'] = '$limit';
  }
  var uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets',
  );
  if (qp.isNotEmpty) {
    uri = uri.replace(queryParameters: qp);
  }
  final res = await http
      .get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListAssetsResponse.fromJson(map);
}
