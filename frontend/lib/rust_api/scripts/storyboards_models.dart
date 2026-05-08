/// Script-side storyboard and batch generation data models.
class ScriptRow {
  const ScriptRow({
    required this.id,
    required this.projectId,
    required this.numericId,
    this.name,
    this.content,
    this.extractState,
    this.createTimeMs,
  });

  final String id;
  final String projectId;
  final int numericId;
  final String? name;
  final String? content;
  final int? extractState;
  final int? createTimeMs;

  factory ScriptRow.fromJson(Map<String, dynamic> json) {
    return ScriptRow(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
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

/// Linked asset brief on **`POST …/projects/{project_id}/scripts/get-script-api`** — JSON **`id`** = **`app_asset`** numeric id.
class ScriptRelatedAssetBrief {
  const ScriptRelatedAssetBrief({required this.numericId, required this.name});

  final int numericId;
  final String name;

  factory ScriptRelatedAssetBrief.fromJson(Map<String, dynamic> json) {
    return ScriptRelatedAssetBrief(
      numericId: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}

/// One script row from **`POST …/projects/{project_id}/scripts/get-script-api`** (camelCase **`extractState`**, **`relatedAssets`**, …).
class ScriptWorkbenchDetailRow {
  const ScriptWorkbenchDetailRow({
    required this.numericId,
    this.name,
    this.content,
    this.extractState,
    this.errorReason,
    this.createTime,
    required this.relatedAssets,
  });

  final int numericId;
  final String? name;
  final String? content;
  final int? extractState;
  final String? errorReason;
  final int? createTime;
  final List<ScriptRelatedAssetBrief> relatedAssets;

  factory ScriptWorkbenchDetailRow.fromJson(Map<String, dynamic> json) {
    final raw = json['relatedAssets'] as List<dynamic>? ?? [];
    return ScriptWorkbenchDetailRow(
      numericId: (json['id'] as num).toInt(),
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
            (e) => ScriptRelatedAssetBrief.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Row from **`POST /api/v1/scripts/extract-state/poll`** — OpenAPI **`ScriptExtractStatePollRow`**.
class ScriptExtractStatePollRow {
  const ScriptExtractStatePollRow({
    required this.numericId,
    this.extractState,
    this.errorReason,
  });

  final int numericId;
  final int? extractState;
  final String? errorReason;

  factory ScriptExtractStatePollRow.fromJson(Map<String, dynamic> json) {
    return ScriptExtractStatePollRow(
      numericId: (json['numeric_id'] as num).toInt(),
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
    required this.numericId,
    this.numericScriptId,
    this.prompt,
    this.filePath,
    this.duration,
    this.state,
    this.trackId,
    this.reason,
    this.track,
    this.videoDesc,
    this.shouldGenerateImage,
    this.numericProjectId,
    this.flowId,
    this.sbIndex,
    this.createTimeMs,
  });

  final String id;
  final String scriptId;
  final int numericId;
  final int? numericScriptId;
  final String? prompt;
  final String? filePath;
  final String? duration;
  final String? state;
  final int? trackId;
  final String? reason;
  final String? track;
  final String? videoDesc;
  final int? shouldGenerateImage;
  final int? numericProjectId;
  final int? flowId;
  final int? sbIndex;
  final int? createTimeMs;

  factory StoryboardRow.fromJson(Map<String, dynamic> json) {
    int? ni(String k) => json[k] == null ? null : (json[k] as num).toInt();
    return StoryboardRow(
      id: json['id'] as String,
      scriptId: json['script_id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      numericScriptId: ni('numeric_script_id'),
      prompt: json['prompt'] as String?,
      filePath: json['file_path'] as String?,
      duration: json['duration'] as String?,
      state: json['state'] as String?,
      trackId: ni('track_id'),
      reason: json['reason'] as String?,
      track: json['track'] as String?,
      videoDesc: json['video_desc'] as String?,
      shouldGenerateImage: ni('should_generate_image'),
      numericProjectId: ni('numeric_project_id'),
      flowId: ni('flow_id'),
      sbIndex: ni('sb_index'),
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}
