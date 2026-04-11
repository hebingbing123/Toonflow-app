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

/// Linked asset brief on **`POST …/projects/{project_id}/scripts/get-script-api`** — JSON **`id`** = **`app_asset.legacy_id`**.
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

/// One script row from **`POST …/projects/{project_id}/scripts/get-script-api`** (camelCase **`extractState`**, **`relatedAssets`**, …).
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

class BatchAddScriptItemV1 {
  const BatchAddScriptItemV1({
    required this.scriptName,
    required this.scriptData,
  });

  final String scriptName;
  final String scriptData;

  Map<String, dynamic> toJson() {
    return {'scriptName': scriptName, 'scriptData': scriptData};
  }
}

class BatchAddScriptResponseV1 {
  const BatchAddScriptResponseV1({
    required this.message,
    required this.inserted,
    required this.scripts,
  });

  final String message;
  final int inserted;
  final List<ScriptRow> scripts;

  factory BatchAddScriptResponseV1.fromJson(Map<String, dynamic> json) {
    final rows = json['scripts'] as List<dynamic>? ?? const [];
    return BatchAddScriptResponseV1(
      message: json['message'] as String,
      inserted: (json['inserted'] as num).toInt(),
      scripts: rows
          .map((e) => ScriptRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
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
