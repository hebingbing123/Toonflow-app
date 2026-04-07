import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';

export 'core.dart';
export 'production.dart';

part 'catalog_memory.dart';
part 'assets_api.dart';
part 'jobs_api.dart';
part 'novels_api.dart';
part 'projects_legacy.dart';
part 'scripts_storyboards.dart';
part 'settings_admin.dart';
part 'status_and_auth.dart';
part 'tasks_legacy.dart';

class ProjectRow {
  const ProjectRow({
    required this.id,
    required this.legacyId,
    this.name,
    this.intro,
    this.projectType,
    this.imageModel,
    this.imageQuality,
    this.videoModel,
    this.artStyle,
    this.directorManual,
    this.mode,
    this.videoRatio,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final String? name;
  final String? intro;
  final String? projectType;
  final String? imageModel;
  final String? imageQuality;
  final String? videoModel;
  final String? artStyle;
  final String? directorManual;
  final String? mode;
  final String? videoRatio;
  final int? createTimeMs;

  factory ProjectRow.fromJson(Map<String, dynamic> json) {
    return ProjectRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String?,
      intro: json['intro'] as String?,
      projectType: json['project_type'] as String?,
      imageModel: json['image_model'] as String?,
      imageQuality: json['image_quality'] as String?,
      videoModel: json['video_model'] as String?,
      artStyle: json['art_style'] as String?,
      directorManual: json['director_manual'] as String?,
      mode: json['mode'] as String?,
      videoRatio: json['video_ratio'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// OpenAPI **`BatchGenerateAssetsImageResponse`**.

class ScriptBrief {
  const ScriptBrief({required this.legacyId, this.name, this.extractState});

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
  const ProjectDetail({required this.project, required this.scripts});

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
    required this.novelCount,
    required this.videoCount,
  });

  final int scriptCount;
  final int storyboardCount;
  final int roleCount;
  final int novelCount;
  final int videoCount;

  factory ProjectStats.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num).toInt();
    return ProjectStats(
      scriptCount: n('script_count'),
      storyboardCount: n('storyboard_count'),
      roleCount: n('role_count'),
      novelCount: json['novel_count'] != null
          ? (json['novel_count'] as num).toInt()
          : 0,
      videoCount: n('video_count'),
    );
  }
}

/// One row from **`GET /api/v1/art-styles`** (`ArtStyleRow` in OpenAPI).
class ArtStyleRow {
  const ArtStyleRow({
    required this.id,
    required this.legacyId,
    required this.name,
    this.fileUrl,
    this.label,
    this.prompt,
  });

  final String id;
  final int legacyId;
  final String name;
  final String? fileUrl;
  final String? label;
  final String? prompt;

  factory ArtStyleRow.fromJson(Map<String, dynamic> json) {
    return ArtStyleRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String,
      fileUrl: json['file_url'] as String?,
      label: json['label'] as String?,
      prompt: json['prompt'] as String?,
    );
  }
}

/// **`GET /api/v1/art-styles`** list envelope.
class ListArtStylesResponse {
  const ListArtStylesResponse({required this.items, required this.total});

  final List<ArtStyleRow> items;
  final int total;

  factory ListArtStylesResponse.fromJson(Map<String, dynamic> json) {
    return ListArtStylesResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => ArtStyleRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/art-styles/extract-prompt` — OpenAPI `ExtractArtStylePromptResponse`.
class ExtractArtStylePromptResponse {
  const ExtractArtStylePromptResponse({required this.text});

  final String text;

  factory ExtractArtStylePromptResponse.fromJson(Map<String, dynamic> json) {
    return ExtractArtStylePromptResponse(text: json['text'] as String);
  }
}

/// `POST /api/v1/script-agent/get-plan-data` — OpenAPI `postScriptAgentGetPlanDataV1` (typically **501**).
Future<int> postScriptAgentGetPlanDataV1(
  String accessToken, {
  required int projectId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/get-plan-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'agentType': 'scriptAgent'}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/script-agent/set-plan-data` — OpenAPI `postScriptAgentSetPlanDataV1` (typically **501**).
Future<int> postScriptAgentSetPlanDataV1(
  String accessToken, {
  required int projectId,
  String storySkeleton = '',
  String adaptationStrategy = '',
  List<Map<String, dynamic>> script = const [],
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/set-plan-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'agentType': 'scriptAgent',
          'data': {
            'storySkeleton': storySkeleton,
            'adaptationStrategy': adaptationStrategy,
            'script': script,
          },
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/script-agent/update-data` — OpenAPI `postScriptAgentUpdateDataV1` (typically **501**).
Future<int> postScriptAgentUpdateDataV1(
  String accessToken, {
  required int id,
  String storySkeleton = '',
  String adaptationStrategy = '',
  List<Map<String, dynamic>> script = const [
    {'id': 1, 'content': ''},
  ],
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/update-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'data': {
            'storySkeleton': storySkeleton,
            'adaptationStrategy': adaptationStrategy,
            'script': script,
          },
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/generate` — OpenAPI `postAssetsGenerateV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.generate.image`**); worker **`succeeded`** inserts
/// **`app_asset_image`** (temporary provider **`image_url`**) when **`OPENAI_API_KEY`/`LLM_API_KEY`**
/// is set. **404** unknown project; **429** daily quota; **503** no DB.
Future<int> postAssetsGenerateGenerateV1(
  String accessToken, {
  required int projectId,
  required int assetLegacyId,
  required String model,
  required String resolution,
  required String type,
  required String name,
  required String prompt,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/generate');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'model': model,
          'resolution': resolution,
          'id': assetLegacyId,
          'type': type,
          'name': name,
          'prompt': prompt,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/polish-prompt` — OpenAPI `postAssetsGeneratePolishPromptV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.polish.prompt`**); worker **`succeeded`** with
/// **`result.polished_prompt`** when **`OPENAI_API_KEY`/`LLM_API_KEY`** is set on the server.
/// **404**/**429**/**503** as for **`generate`**.
Future<int> postAssetsGeneratePolishPromptV1(
  String accessToken, {
  required int assetsId,
  required int projectId,
  required String type,
  required String name,
  required String describe,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/polish-prompt');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'assetsId': assetsId,
          'projectId': projectId,
          'type': type,
          'name': name,
          'describe': describe,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/batch-generate` — OpenAPI `postAssetsGenerateBatchGenerateV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.generate.batch`**); worker runs **`images/generations`**
/// per item when LLM keys are set (**`result.items`**). **404**/**429**/**503** as for **`generate`**.
Future<int> postAssetsGenerateBatchGenerateV1(
  String accessToken, {
  required int projectId,
  required String model,
  required String resolution,
  required List<Map<String, dynamic>> items,
  int? concurrentCount,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/batch-generate');
  final body = <String, dynamic>{
    'projectId': projectId,
    'model': model,
    'resolution': resolution,
    'items': items,
  };
  if (concurrentCount != null) body['concurrentCount'] = concurrentCount;
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
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/batch-polish` — OpenAPI `postAssetsGenerateBatchPolishV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.polish.batch`**); worker **`succeeded`** with
/// **`result.items`** (each **`polished_prompt`**) when the server has **`OPENAI_API_KEY`/`LLM_API_KEY`**.
Future<int> postAssetsGenerateBatchPolishV1(
  String accessToken, {
  required int projectId,
  required List<Map<String, dynamic>> items,
  int? concurrentCount,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/batch-polish');
  final body = <String, dynamic>{'projectId': projectId, 'items': items};
  if (concurrentCount != null) body['concurrentCount'] = concurrentCount;
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
  return res.statusCode;
}

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).

// --- Legacy `POST /api/v1/tasks/*` (Electron task center) ---

// --- Legacy `POST /api/v1/project/*` (Electron project CRUD helpers) ---

class SkillFileMeta {
  const SkillFileMeta({required this.path, required this.sizeBytes});

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
  const SkillContentResponse({required this.path, required this.content});

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

/// `GET /api/v1/skills/summary`. See `getSkillsSummaryV1`.
Future<SkillsSummary> fetchSkillsSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
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
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/skills/content',
  ).replace(queryParameters: {'path': relativePath});
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
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

/// `PUT /api/v1/skills/content` — overwrites an **existing** file only (legacy `saveSkillContent`).
/// See `putSkillContentV1`.
Future<SkillContentResponse> saveSkillContent(
  String accessToken,
  String relativePath,
  String content,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content');
  final res = await http
      .put(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'path': relativePath, 'content': content}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillContentResponse.fromJson(map);
}

/// `POST /api/v1/skills/content` — creates a new file under `data/skills` (**409** if it already exists).
/// See `postSkillContentV1`.
Future<SkillContentResponse> createSkillContent(
  String accessToken,
  String relativePath,
  String content,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'path': relativePath, 'content': content}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 409) {
    throw RustApiException('conflict', statusCode: 409);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillContentResponse.fromJson(map);
}

/// `DELETE /api/v1/skills/content?path=…` — removes a regular file only (**204** empty body).
/// See `deleteSkillContentV1`.
Future<void> deleteSkillContent(String accessToken, String relativePath) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/skills/content',
  ).replace(queryParameters: {'path': relativePath});
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `GET /api/v1/harness/tools`. See `listHarnessToolsV1`.
Future<HarnessToolsResponse> fetchHarnessTools(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/harness/tools');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
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

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
