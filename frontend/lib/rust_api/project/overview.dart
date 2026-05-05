import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class ProjectRow {
  const ProjectRow({
    required this.id,
    required this.numericId,
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
    this.artStylePack,
    this.storyStylePack,
    this.targetMarket,
    this.targetPlatforms,
    this.durationStrategy,
    this.voiceProfile,
    this.subtitleStyle,
    this.bgmStrategy,
  });

  final String id;
  final int numericId;
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
  final String? artStylePack;
  final String? storyStylePack;
  /// `domestic` / `overseas` / `both`
  final String? targetMarket;
  final List<String>? targetPlatforms;
  /// `short` / `medium` / `long`
  final String? durationStrategy;
  final String? voiceProfile;
  final String? subtitleStyle;
  final String? bgmStrategy;

  factory ProjectRow.fromJson(Map<String, dynamic> json) {
    List<String>? platforms;
    final tp = json['target_platforms'];
    if (tp is List<dynamic>) {
      platforms = tp.map((e) => e.toString()).toList(growable: false);
    }
    return ProjectRow(
      id: json['id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
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
      artStylePack: json['art_style_pack'] as String?,
      storyStylePack: json['story_style_pack'] as String?,
      targetMarket: json['target_market'] as String?,
      targetPlatforms: platforms,
      durationStrategy: json['duration_strategy'] as String?,
      voiceProfile: json['voice_profile'] as String?,
      subtitleStyle: json['subtitle_style'] as String?,
      bgmStrategy: json['bgm_strategy'] as String?,
    );
  }
}

/// OpenAPI **`BatchGenerateAssetsImageResponse`**.

class ScriptBrief {
  const ScriptBrief({required this.numericId, this.name, this.extractState});

  final int numericId;
  final String? name;
  final int? extractState;

  factory ScriptBrief.fromJson(Map<String, dynamic> json) {
    return ScriptBrief(
      numericId: (json['numeric_id'] as num).toInt(),
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

/// `GET /api/v1/projects/{project_id}/short-video-readiness` — see `getProjectShortVideoReadinessByProjectIdV1`.

class ShortVideoReadinessReasonRollup {
  const ShortVideoReadinessReasonRollup({
    required this.reason,
    required this.storyboardCount,
  });

  final String reason;
  final int storyboardCount;

  factory ShortVideoReadinessReasonRollup.fromJson(Map<String, dynamic> json) {
    return ShortVideoReadinessReasonRollup(
      reason: json['reason'] as String,
      storyboardCount: (json['storyboard_count'] as num).toInt(),
    );
  }
}

class ShortVideoReadinessRollup {
  const ShortVideoReadinessRollup({
    required this.totalStoryboards,
    required this.readyCount,
    required this.blockedCount,
    required this.byReason,
  });

  final int totalStoryboards;
  final int readyCount;
  final int blockedCount;
  final List<ShortVideoReadinessReasonRollup> byReason;

  factory ShortVideoReadinessRollup.fromJson(Map<String, dynamic> json) {
    final raw = json['by_reason'] as List<dynamic>? ?? const <dynamic>[];
    return ShortVideoReadinessRollup(
      totalStoryboards: (json['total_storyboards'] as num).toInt(),
      readyCount: (json['ready_count'] as num).toInt(),
      blockedCount: (json['blocked_count'] as num).toInt(),
      byReason: raw
          .map(
            (e) => ShortVideoReadinessReasonRollup.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class StoryboardShortVideoReadiness {
  const StoryboardShortVideoReadiness({
    required this.storyboardId,
    required this.storyboardNumericId,
    this.scriptNumericId,
    this.sbIndex,
    required this.hasBasicSlot,
    required this.hasPromptContext,
    required this.hasReferenceVisual,
    required this.candidateCleared,
    required this.noBlockingJob,
    required this.readyForGeneration,
    required this.blockingReasons,
  });

  final String storyboardId;
  final int storyboardNumericId;
  final int? scriptNumericId;
  final int? sbIndex;
  final bool hasBasicSlot;
  final bool hasPromptContext;
  final bool hasReferenceVisual;
  final bool candidateCleared;
  final bool noBlockingJob;
  final bool readyForGeneration;
  final List<String> blockingReasons;

  factory StoryboardShortVideoReadiness.fromJson(Map<String, dynamic> json) {
    final reasons = json['blocking_reasons'] as List<dynamic>? ?? const <dynamic>[];
    return StoryboardShortVideoReadiness(
      storyboardId: json['storyboard_id'] as String,
      storyboardNumericId: (json['storyboard_numeric_id'] as num).toInt(),
      scriptNumericId: json['script_numeric_id'] == null
          ? null
          : (json['script_numeric_id'] as num).toInt(),
      sbIndex: json['sb_index'] == null
          ? null
          : (json['sb_index'] as num).toInt(),
      hasBasicSlot: json['has_basic_slot'] as bool,
      hasPromptContext: json['has_prompt_context'] as bool,
      hasReferenceVisual: json['has_reference_visual'] as bool,
      candidateCleared: json['candidate_cleared'] as bool,
      noBlockingJob: json['no_blocking_job'] as bool,
      readyForGeneration: json['ready_for_generation'] as bool,
      blockingReasons: reasons.map((e) => e.toString()).toList(),
    );
  }
}

class ProjectShortVideoReadiness {
  const ProjectShortVideoReadiness({
    required this.schemaVersion,
    required this.rollup,
    required this.storyboards,
  });

  final int schemaVersion;
  final ShortVideoReadinessRollup rollup;
  final List<StoryboardShortVideoReadiness> storyboards;

  factory ProjectShortVideoReadiness.fromJson(Map<String, dynamic> json) {
    final sb = json['storyboards'] as List<dynamic>? ?? const <dynamic>[];
    return ProjectShortVideoReadiness(
      schemaVersion: (json['schema_version'] as num).toInt(),
      rollup: ShortVideoReadinessRollup.fromJson(
        json['rollup'] as Map<String, dynamic>,
      ),
      storyboards: sb
          .map(
            (e) => StoryboardShortVideoReadiness.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// `GET /api/v1/projects/{project_id}/production-overview` — see `getProjectProductionOverviewByProjectIdV1`.
class ProjectProductionOverview {
  const ProjectProductionOverview({
    required this.schemaVersion,
    required this.readyStoryboardCount,
    required this.totalStoryboardCount,
    required this.runningGenerationJobCount,
    required this.pendingReviewBadCaseCount,
  });

  final int schemaVersion;
  final int readyStoryboardCount;
  final int totalStoryboardCount;
  final int runningGenerationJobCount;
  final int pendingReviewBadCaseCount;

  factory ProjectProductionOverview.fromJson(Map<String, dynamic> json) {
    return ProjectProductionOverview(
      schemaVersion: (json['schema_version'] as num).toInt(),
      readyStoryboardCount: (json['ready_storyboard_count'] as num).toInt(),
      totalStoryboardCount: (json['total_storyboard_count'] as num).toInt(),
      runningGenerationJobCount:
          (json['running_generation_job_count'] as num).toInt(),
      pendingReviewBadCaseCount:
          (json['pending_review_bad_case_count'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/projects/{project_id}/assets-overview` — see `getProjectAssetsOverviewByProjectIdV1`.

class AssetsOverviewCandidateCounts {
  const AssetsOverviewCandidateCounts({
    required this.pending,
    required this.linked,
    required this.ignored,
    required this.unset,
  });

  final int pending;
  final int linked;
  final int ignored;
  final int unset;

  factory AssetsOverviewCandidateCounts.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num).toInt();
    return AssetsOverviewCandidateCounts(
      pending: n('pending'),
      linked: n('linked'),
      ignored: n('ignored'),
      unset: n('unset'),
    );
  }
}

class AssetsOverviewItem {
  const AssetsOverviewItem({
    required this.assetId,
    required this.numericId,
    required this.name,
    required this.assetType,
    this.candidateStatus,
    required this.linkedScriptNumericIds,
  });

  final String assetId;
  final int numericId;
  final String name;
  final String assetType;
  final String? candidateStatus;
  final List<int> linkedScriptNumericIds;

  factory AssetsOverviewItem.fromJson(Map<String, dynamic> json) {
    final raw = json['linked_script_numeric_ids'] as List<dynamic>? ??
        const <dynamic>[];
    return AssetsOverviewItem(
      assetId: json['asset_id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      candidateStatus: json['candidate_status'] as String?,
      linkedScriptNumericIds:
          raw.map((e) => (e as num).toInt()).toList(growable: false),
    );
  }
}

class AssetsOverviewTypeGroup {
  const AssetsOverviewTypeGroup({
    required this.assetType,
    required this.items,
  });

  final String assetType;
  final List<AssetsOverviewItem> items;

  factory AssetsOverviewTypeGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return AssetsOverviewTypeGroup(
      assetType: json['asset_type'] as String,
      items: raw
          .map((e) => AssetsOverviewItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class ProjectAssetsOverview {
  const ProjectAssetsOverview({
    required this.schemaVersion,
    required this.totalCount,
    required this.candidateCounts,
    required this.byAssetType,
  });

  final int schemaVersion;
  final int totalCount;
  final AssetsOverviewCandidateCounts candidateCounts;
  final List<AssetsOverviewTypeGroup> byAssetType;

  factory ProjectAssetsOverview.fromJson(Map<String, dynamic> json) {
    final groups =
        json['by_asset_type'] as List<dynamic>? ?? const <dynamic>[];
    return ProjectAssetsOverview(
      schemaVersion: (json['schema_version'] as num).toInt(),
      totalCount: (json['total_count'] as num).toInt(),
      candidateCounts: AssetsOverviewCandidateCounts.fromJson(
        json['candidate_counts'] as Map<String, dynamic>,
      ),
      byAssetType: groups
          .map(
            (e) => AssetsOverviewTypeGroup.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

/// `GET /api/v1/projects/{project_id}/short-video-assembly` — see `getProjectShortVideoAssemblyByProjectIdV1`.

class ShortVideoAssemblyProjectDefaults {
  const ShortVideoAssemblyProjectDefaults({
    this.voiceProfile,
    this.subtitleStyle,
    this.bgmStrategy,
  });

  final String? voiceProfile;
  final String? subtitleStyle;
  final String? bgmStrategy;

  factory ShortVideoAssemblyProjectDefaults.fromJson(Map<String, dynamic> json) {
    return ShortVideoAssemblyProjectDefaults(
      voiceProfile: json['voice_profile'] as String?,
      subtitleStyle: json['subtitle_style'] as String?,
      bgmStrategy: json['bgm_strategy'] as String?,
    );
  }
}

/// D7：与后端 enqueue / worker 一致的成片侧生效默认（JSON **`effective_short_video_defaults`**）。
class ShortVideoAssemblyEffectiveDefaults {
  const ShortVideoAssemblyEffectiveDefaults({
    required this.ttsVoice,
    this.subtitleStyle,
    this.bgmStrategy,
  });

  final String ttsVoice;
  final String? subtitleStyle;
  final String? bgmStrategy;

  factory ShortVideoAssemblyEffectiveDefaults.fromJson(Map<String, dynamic> json) {
    return ShortVideoAssemblyEffectiveDefaults(
      ttsVoice: json['tts_voice'] as String,
      subtitleStyle: json['subtitle_style'] as String?,
      bgmStrategy: json['bgm_strategy'] as String?,
    );
  }

  /// Older API payloads without **`effective_short_video_defaults`**（与 Rust **`resolve_tts_voice`** 对齐）。
  factory ShortVideoAssemblyEffectiveDefaults.inferredFromProjectDefaults(
    ShortVideoAssemblyProjectDefaults pd,
  ) {
    final vp = (pd.voiceProfile ?? '').trim();
    return ShortVideoAssemblyEffectiveDefaults(
      ttsVoice: vp.isEmpty ? 'alloy' : vp,
      subtitleStyle: pd.subtitleStyle,
      bgmStrategy: pd.bgmStrategy,
    );
  }
}

class ShortVideoAssemblyShot {
  const ShortVideoAssemblyShot({
    required this.storyboardId,
    required this.storyboardNumericId,
    this.sbIndex,
    this.selectedMediaUrl,
    required this.selectedMediaKind,
    this.duration,
    this.state,
    this.trackId,
    this.subtitleText,
    required this.subtitleSource,
    required this.voiceoverScriptReady,
    this.voiceoverState,
    this.voiceoverAudioUrl,
    this.voiceoverError,
    required this.voiceoverAssetReady,
  });

  final String storyboardId;
  final int storyboardNumericId;
  final int? sbIndex;
  final String? selectedMediaUrl;
  final String selectedMediaKind;
  final String? duration;
  final String? state;
  final int? trackId;
  final String? subtitleText;
  final String subtitleSource;
  final bool voiceoverScriptReady;
  final String? voiceoverState;
  final String? voiceoverAudioUrl;
  final String? voiceoverError;
  final bool voiceoverAssetReady;

  factory ShortVideoAssemblyShot.fromJson(Map<String, dynamic> json) {
    return ShortVideoAssemblyShot(
      storyboardId: json['storyboard_id'] as String,
      storyboardNumericId: (json['storyboard_numeric_id'] as num).toInt(),
      sbIndex: json['sb_index'] == null
          ? null
          : (json['sb_index'] as num).toInt(),
      selectedMediaUrl: json['selected_media_url'] as String?,
      selectedMediaKind: json['selected_media_kind'] as String,
      duration: json['duration'] as String?,
      state: json['state'] as String?,
      trackId: json['track_id'] == null
          ? null
          : (json['track_id'] as num).toInt(),
      subtitleText: json['subtitle_text'] as String?,
      subtitleSource: json['subtitle_source'] as String,
      voiceoverScriptReady: json['voiceover_script_ready'] as bool,
      voiceoverState: json['voiceover_state'] as String?,
      voiceoverAudioUrl: json['voiceover_audio_url'] as String?,
      voiceoverError: json['voiceover_error'] as String?,
      voiceoverAssetReady: json['voiceover_asset_ready'] as bool,
    );
  }
}

class ShortVideoAssemblyScriptGroup {
  const ShortVideoAssemblyScriptGroup({
    required this.scriptNumericId,
    this.scriptName,
    required this.shots,
  });

  final int scriptNumericId;
  final String? scriptName;
  final List<ShortVideoAssemblyShot> shots;

  factory ShortVideoAssemblyScriptGroup.fromJson(Map<String, dynamic> json) {
    final raw = json['shots'] as List<dynamic>? ?? const <dynamic>[];
    return ShortVideoAssemblyScriptGroup(
      scriptNumericId: (json['script_numeric_id'] as num).toInt(),
      scriptName: json['script_name'] as String?,
      shots: raw
          .map((e) => ShortVideoAssemblyShot.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class ProjectShortVideoAssembly {
  const ProjectShortVideoAssembly({
    required this.schemaVersion,
    required this.projectDefaults,
    required this.effectiveShortVideoDefaults,
    required this.scripts,
  });

  final int schemaVersion;
  final ShortVideoAssemblyProjectDefaults projectDefaults;
  final ShortVideoAssemblyEffectiveDefaults effectiveShortVideoDefaults;
  final List<ShortVideoAssemblyScriptGroup> scripts;

  factory ProjectShortVideoAssembly.fromJson(Map<String, dynamic> json) {
    final raw = json['scripts'] as List<dynamic>? ?? const <dynamic>[];
    final pd = ShortVideoAssemblyProjectDefaults.fromJson(
      json['project_defaults'] as Map<String, dynamic>,
    );
    final effRaw = json['effective_short_video_defaults'];
    return ProjectShortVideoAssembly(
      schemaVersion: (json['schema_version'] as num).toInt(),
      projectDefaults: pd,
      effectiveShortVideoDefaults: effRaw is Map<String, dynamic>
          ? ShortVideoAssemblyEffectiveDefaults.fromJson(effRaw)
          : ShortVideoAssemblyEffectiveDefaults.inferredFromProjectDefaults(pd),
      scripts: raw
          .map(
            (e) =>
                ShortVideoAssemblyScriptGroup.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

/// Models for **`GET /api/v1/projects/{project_id}/short-video-export-check`** (`getProjectShortVideoExportCheckByProjectIdV1`).
class ShortVideoExportCheckSummary {
  const ShortVideoExportCheckSummary({
    required this.storyboardCount,
    required this.blockingIssueCount,
    required this.warningIssueCount,
  });

  final int storyboardCount;
  final int blockingIssueCount;
  final int warningIssueCount;

  factory ShortVideoExportCheckSummary.fromJson(Map<String, dynamic> json) {
    return ShortVideoExportCheckSummary(
      storyboardCount: (json['storyboard_count'] as num).toInt(),
      blockingIssueCount: (json['blocking_issue_count'] as num).toInt(),
      warningIssueCount: (json['warning_issue_count'] as num).toInt(),
    );
  }
}

class ShortVideoExportCheckIssue {
  const ShortVideoExportCheckIssue({
    required this.severity,
    required this.code,
    required this.detail,
    required this.scriptNumericId,
    required this.storyboardId,
    required this.storyboardNumericId,
    this.sbIndex,
  });

  final String severity;
  final String code;
  final String detail;
  final int scriptNumericId;
  final String storyboardId;
  final int storyboardNumericId;
  final int? sbIndex;

  factory ShortVideoExportCheckIssue.fromJson(Map<String, dynamic> json) {
    return ShortVideoExportCheckIssue(
      severity: json['severity'] as String,
      code: json['code'] as String,
      detail: json['detail'] as String,
      scriptNumericId: (json['script_numeric_id'] as num).toInt(),
      storyboardId: json['storyboard_id'] as String,
      storyboardNumericId: (json['storyboard_numeric_id'] as num).toInt(),
      sbIndex: json['sb_index'] == null
          ? null
          : (json['sb_index'] as num).toInt(),
    );
  }
}

class ShortVideoExportQualityGatePlaceholder {
  const ShortVideoExportQualityGatePlaceholder({
    required this.schemaVersion,
    required this.enforced,
    required this.pendingReviewBadCaseCount,
  });

  final int schemaVersion;
  final bool enforced;
  final int pendingReviewBadCaseCount;

  factory ShortVideoExportQualityGatePlaceholder.fromJson(
    Map<String, dynamic> json,
  ) {
    return ShortVideoExportQualityGatePlaceholder(
      schemaVersion: (json['schema_version'] as num).toInt(),
      enforced: json['enforced'] as bool,
      pendingReviewBadCaseCount:
          (json['pending_review_bad_case_count'] as num).toInt(),
    );
  }
}

class ProjectShortVideoExportCheck {
  const ProjectShortVideoExportCheck({
    required this.schemaVersion,
    required this.exportReady,
    required this.summary,
    required this.issues,
    required this.qualityGatePlaceholder,
  });

  final int schemaVersion;
  final bool exportReady;
  final ShortVideoExportCheckSummary summary;
  final List<ShortVideoExportCheckIssue> issues;
  final ShortVideoExportQualityGatePlaceholder qualityGatePlaceholder;

  factory ProjectShortVideoExportCheck.fromJson(Map<String, dynamic> json) {
    final raw = json['issues'] as List<dynamic>? ?? const <dynamic>[];
    final qgRaw = json['quality_gate_placeholder'];
    return ProjectShortVideoExportCheck(
      schemaVersion: (json['schema_version'] as num).toInt(),
      exportReady: json['export_ready'] as bool,
      summary: ShortVideoExportCheckSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      issues: raw
          .map(
            (e) =>
                ShortVideoExportCheckIssue.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      qualityGatePlaceholder: qgRaw is Map<String, dynamic>
          ? ShortVideoExportQualityGatePlaceholder.fromJson(qgRaw)
          : const ShortVideoExportQualityGatePlaceholder(
              schemaVersion: 1,
              enforced: false,
              pendingReviewBadCaseCount: 0,
            ),
    );
  }
}

/// `GET /api/v1/projects/{project_id}` — see `getProjectByProjectIdV1`.
Future<ProjectDetail> fetchProjectByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId');
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

/// `GET /api/v1/projects/{project_id}/stats` — see `getProjectStatsByProjectIdV1`.
Future<ProjectStats> fetchProjectStatsByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/stats');
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

/// `GET /api/v1/projects/{project_id}/short-video-readiness` — see `getProjectShortVideoReadinessByProjectIdV1`.
Future<ProjectShortVideoReadiness> fetchProjectShortVideoReadinessByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-readiness',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectShortVideoReadiness.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/production-overview` — see `getProjectProductionOverviewByProjectIdV1`.
Future<ProjectProductionOverview> fetchProjectProductionOverviewByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/production-overview',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectProductionOverview.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/assets-overview` — see `getProjectAssetsOverviewByProjectIdV1`.
Future<ProjectAssetsOverview> fetchProjectAssetsOverviewByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets-overview',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectAssetsOverview.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/short-video-assembly` — see `getProjectShortVideoAssemblyByProjectIdV1`.
Future<ProjectShortVideoAssembly> fetchProjectShortVideoAssemblyByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-assembly',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 25));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectShortVideoAssembly.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/short-video-export-check` — see `getProjectShortVideoExportCheckByProjectIdV1`.
Future<ProjectShortVideoExportCheck> fetchProjectShortVideoExportCheckByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-export-check',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 25));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectShortVideoExportCheck.fromJson(map);
}

/// Maps backend **`blocking_reasons`** codes to short UI labels (Chinese).
String labelShortVideoBlockingReason(String code) {
  switch (code) {
    case 'missing_basic_slot':
      return '时间线槽位';
    case 'missing_prompt_context':
      return '脚本 / 提示词';
    case 'missing_reference_visual':
      return '参考图';
    case 'candidate_pending':
      return '候选确认';
    case 'blocking_job':
      return '生成任务进行中';
    default:
      return code;
  }
}

/// One-line summary for the storyboard workbench (current shot).
String formatStoryboardShortVideoReadinessSummary(
  StoryboardShortVideoReadiness row,
) {
  if (row.readyForGeneration) {
    return '短视频就绪：本条分镜检查已通过，可继续生成。';
  }
  final parts = row.blockingReasons.map(labelShortVideoBlockingReason).toList();
  if (parts.isEmpty) {
    return '短视频就绪：有待核对项。';
  }
  return '短视频就绪：待补齐 ${parts.join('、')}';
}
