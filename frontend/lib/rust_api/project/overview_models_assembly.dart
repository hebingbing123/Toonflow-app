// Project overview data models - Part 2: Assets, assembly, and export models

import 'overview_models.dart' show ProjectHomeLaunchIntent;

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
    final raw =
        json['linked_script_numeric_ids'] as List<dynamic>? ??
        const <dynamic>[];
    return AssetsOverviewItem(
      assetId: json['asset_id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      candidateStatus: json['candidate_status'] as String?,
      linkedScriptNumericIds: raw
          .map((e) => (e as num).toInt())
          .toList(growable: false),
    );
  }
}

class AssetsOverviewTypeGroup {
  const AssetsOverviewTypeGroup({required this.assetType, required this.items});

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

class AssetsOverviewHubAction {
  const AssetsOverviewHubAction({
    required this.key,
    required this.title,
    required this.detail,
    required this.targetStep,
    required this.ctaLabel,
    this.launchIntent,
  });

  final String key;
  final String title;
  final String detail;
  final String targetStep;
  final String ctaLabel;
  final ProjectHomeLaunchIntent? launchIntent;

  factory AssetsOverviewHubAction.fromJson(Map<String, dynamic> json) {
    return AssetsOverviewHubAction(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      targetStep: json['target_step'] as String? ?? 'assets',
      ctaLabel: json['cta_label'] as String? ?? '',
      launchIntent: ProjectHomeLaunchIntent.parseRequired(
        json['launch_intent'],
        context: 'AssetsOverviewHubAction',
      ),
    );
  }
}

class AssetsOverviewHubMetric {
  const AssetsOverviewHubMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.detail,
    this.launchIntent,
  });

  final String key;
  final String label;
  final String value;
  final String detail;
  final ProjectHomeLaunchIntent? launchIntent;

  factory AssetsOverviewHubMetric.fromJson(Map<String, dynamic> json) {
    return AssetsOverviewHubMetric(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      launchIntent: ProjectHomeLaunchIntent.parseRequired(
        json['launch_intent'],
        context: 'AssetsOverviewHubMetric',
      ),
    );
  }
}

class AssetsOverviewCharacterSummary {
  const AssetsOverviewCharacterSummary({
    required this.characterId,
    required this.name,
    this.assetId,
    this.assetName,
    required this.linkedScriptNumericIds,
    required this.hasVoiceConfig,
    required this.missingAssetAnchor,
  });

  final String characterId;
  final String name;
  final String? assetId;
  final String? assetName;
  final List<int> linkedScriptNumericIds;
  final bool hasVoiceConfig;
  final bool missingAssetAnchor;

  factory AssetsOverviewCharacterSummary.fromJson(Map<String, dynamic> json) {
    final raw =
        json['linked_script_numeric_ids'] as List<dynamic>? ??
        const <dynamic>[];
    return AssetsOverviewCharacterSummary(
      characterId: json['character_id'] as String,
      name: json['name'] as String? ?? '',
      assetId: json['asset_id'] as String?,
      assetName: json['asset_name'] as String?,
      linkedScriptNumericIds: raw
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      hasVoiceConfig: json['has_voice_config'] as bool? ?? false,
      missingAssetAnchor: json['missing_asset_anchor'] as bool? ?? false,
    );
  }
}

class AssetsOverviewRoleSummary {
  const AssetsOverviewRoleSummary({
    required this.assetId,
    required this.numericId,
    required this.name,
    this.candidateStatus,
    required this.linkedScriptNumericIds,
    required this.linkedCharacterNames,
  });

  final String assetId;
  final int numericId;
  final String name;
  final String? candidateStatus;
  final List<int> linkedScriptNumericIds;
  final List<String> linkedCharacterNames;

  factory AssetsOverviewRoleSummary.fromJson(Map<String, dynamic> json) {
    final scripts =
        json['linked_script_numeric_ids'] as List<dynamic>? ??
        const <dynamic>[];
    final names =
        json['linked_character_names'] as List<dynamic>? ?? const <dynamic>[];
    return AssetsOverviewRoleSummary(
      assetId: json['asset_id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      candidateStatus: json['candidate_status'] as String?,
      linkedScriptNumericIds: scripts
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      linkedCharacterNames: names
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

class AssetsOverviewHub {
  const AssetsOverviewHub({
    required this.headline,
    required this.subheadline,
    required this.primaryAction,
    required this.metrics,
    required this.characterSummaries,
    required this.reusableRoleAssets,
  });

  final String headline;
  final String subheadline;
  final AssetsOverviewHubAction primaryAction;
  final List<AssetsOverviewHubMetric> metrics;
  final List<AssetsOverviewCharacterSummary> characterSummaries;
  final List<AssetsOverviewRoleSummary> reusableRoleAssets;

  const AssetsOverviewHub.empty()
    : headline = '',
      subheadline = '',
      primaryAction = const AssetsOverviewHubAction(
        key: '',
        title: '',
        detail: '',
        targetStep: 'assets',
        ctaLabel: '',
        launchIntent: null,
      ),
      metrics = const <AssetsOverviewHubMetric>[],
      characterSummaries = const <AssetsOverviewCharacterSummary>[],
      reusableRoleAssets = const <AssetsOverviewRoleSummary>[];

  factory AssetsOverviewHub.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] as List<dynamic>? ?? const <dynamic>[];
    final characters =
        json['character_summaries'] as List<dynamic>? ?? const <dynamic>[];
    final roles =
        json['reusable_role_assets'] as List<dynamic>? ?? const <dynamic>[];
    return AssetsOverviewHub(
      headline: json['headline'] as String? ?? '',
      subheadline: json['subheadline'] as String? ?? '',
      primaryAction: AssetsOverviewHubAction.fromJson(
        json['primary_action'] as Map<String, dynamic>,
      ),
      metrics: metrics
          .map(
            (e) => AssetsOverviewHubMetric.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      characterSummaries: characters
          .map(
            (e) => AssetsOverviewCharacterSummary.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      reusableRoleAssets: roles
          .map(
            (e) =>
                AssetsOverviewRoleSummary.fromJson(e as Map<String, dynamic>),
          )
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
    required this.hub,
  });

  final int schemaVersion;
  final int totalCount;
  final AssetsOverviewCandidateCounts candidateCounts;
  final List<AssetsOverviewTypeGroup> byAssetType;
  final AssetsOverviewHub hub;

  factory ProjectAssetsOverview.fromJson(Map<String, dynamic> json) {
    final groups = json['by_asset_type'] as List<dynamic>? ?? const <dynamic>[];
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
      hub: json['hub'] is Map<String, dynamic>
          ? AssetsOverviewHub.fromJson(json['hub'] as Map<String, dynamic>)
          : const AssetsOverviewHub.empty(),
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

  factory ShortVideoAssemblyProjectDefaults.fromJson(
    Map<String, dynamic> json,
  ) {
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

  factory ShortVideoAssemblyEffectiveDefaults.fromJson(
    Map<String, dynamic> json,
  ) {
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

class ShortVideoAssemblyShotExportGap {
  const ShortVideoAssemblyShotExportGap({
    required this.gapCodes,
    required this.hasBlocking,
    required this.missingSelectedVideo,
    required this.missingSubtitle,
    required this.missingVoiceover,
    required this.durationAnomaly,
  });

  final List<String> gapCodes;
  final bool hasBlocking;
  final bool missingSelectedVideo;
  final bool missingSubtitle;
  final bool missingVoiceover;
  final bool durationAnomaly;

  factory ShortVideoAssemblyShotExportGap.fromJson(Map<String, dynamic> json) {
    final codes = json['gap_codes'] as List<dynamic>? ?? const <dynamic>[];
    return ShortVideoAssemblyShotExportGap(
      gapCodes: codes.map((e) => e as String).toList(growable: false),
      hasBlocking: json['has_blocking'] as bool? ?? false,
      missingSelectedVideo: json['missing_selected_video'] as bool? ?? false,
      missingSubtitle: json['missing_subtitle'] as bool? ?? false,
      missingVoiceover: json['missing_voiceover'] as bool? ?? false,
      durationAnomaly: json['duration_anomaly'] as bool? ?? false,
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
    required this.exportGap,
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
  final ShortVideoAssemblyShotExportGap exportGap;

  factory ShortVideoAssemblyShot.fromJson(Map<String, dynamic> json) {
    final gapRaw = json['export_gap'];
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
      exportGap: gapRaw is Map<String, dynamic>
          ? ShortVideoAssemblyShotExportGap.fromJson(gapRaw)
          : const ShortVideoAssemblyShotExportGap(
              gapCodes: <String>[],
              hasBlocking: false,
              missingSelectedVideo: false,
              missingSubtitle: false,
              missingVoiceover: false,
              durationAnomaly: false,
            ),
    );
  }
}

class ShortVideoPreAssemblySummary {
  const ShortVideoPreAssemblySummary({
    required this.shotCount,
    required this.blockingShotCount,
    required this.readyVideoCount,
    required this.readyVoiceoverCount,
    required this.totalDurationSeconds,
  });

  final int shotCount;
  final int blockingShotCount;
  final int readyVideoCount;
  final int readyVoiceoverCount;
  final int totalDurationSeconds;

  factory ShortVideoPreAssemblySummary.fromJson(Map<String, dynamic> json) {
    return ShortVideoPreAssemblySummary(
      shotCount: (json['shot_count'] as num).toInt(),
      blockingShotCount: (json['blocking_shot_count'] as num).toInt(),
      readyVideoCount: (json['ready_video_count'] as num).toInt(),
      readyVoiceoverCount: (json['ready_voiceover_count'] as num).toInt(),
      totalDurationSeconds: (json['total_duration_seconds'] as num).toInt(),
    );
  }
}

class ShortVideoPreAssemblyEnqueueResponse {
  const ShortVideoPreAssemblyEnqueueResponse({
    required this.schemaVersion,
    required this.jobId,
    required this.summary,
  });

  final int schemaVersion;
  final String jobId;
  final ShortVideoPreAssemblySummary summary;

  factory ShortVideoPreAssemblyEnqueueResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ShortVideoPreAssemblyEnqueueResponse(
      schemaVersion: (json['schema_version'] as num).toInt(),
      jobId: json['job_id'] as String,
      summary: ShortVideoPreAssemblySummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
    );
  }
}

class ShortVideoExportEnqueueResponse {
  const ShortVideoExportEnqueueResponse({
    required this.schemaVersion,
    required this.jobId,
    required this.sourceUrl,
  });

  final int schemaVersion;
  final String jobId;
  final String sourceUrl;

  factory ShortVideoExportEnqueueResponse.fromJson(Map<String, dynamic> json) {
    return ShortVideoExportEnqueueResponse(
      schemaVersion: (json['schema_version'] as num).toInt(),
      jobId: json['job_id'] as String,
      sourceUrl: json['source_url'] as String,
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
          .map(
            (e) => ShortVideoAssemblyShot.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

/// L3：与装配分镜对齐的质量评审摘要（**`candidate_quality_summary`**）。
class ShortVideoCandidateQualitySummary {
  const ShortVideoCandidateQualitySummary({
    required this.schemaVersion,
    required this.projectBadCaseTotal,
    required this.assemblyShotReviewTotal,
    required this.assemblyShotBadCaseCount,
    required this.assemblyShotsWithBadCase,
    required this.assemblyLateStageBadCaseCount,
    required this.badCasesByStage,
  });

  final int schemaVersion;
  final int projectBadCaseTotal;
  final int assemblyShotReviewTotal;
  final int assemblyShotBadCaseCount;
  final int assemblyShotsWithBadCase;
  final int assemblyLateStageBadCaseCount;
  final List<ShortVideoQualityStageBucket> badCasesByStage;

  factory ShortVideoCandidateQualitySummary.fromJson(
    Map<String, dynamic> json,
  ) {
    final buckets =
        json['bad_cases_by_stage'] as List<dynamic>? ?? const <dynamic>[];
    return ShortVideoCandidateQualitySummary(
      schemaVersion: (json['schema_version'] as num).toInt(),
      projectBadCaseTotal: (json['project_bad_case_total'] as num).toInt(),
      assemblyShotReviewTotal: (json['assembly_shot_review_total'] as num)
          .toInt(),
      assemblyShotBadCaseCount: (json['assembly_shot_bad_case_count'] as num)
          .toInt(),
      assemblyShotsWithBadCase: (json['assembly_shots_with_bad_case'] as num)
          .toInt(),
      assemblyLateStageBadCaseCount:
          (json['assembly_late_stage_bad_case_count'] as num).toInt(),
      badCasesByStage: buckets
          .map(
            (e) => ShortVideoQualityStageBucket.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Older servers without **`candidate_quality_summary`**.
  factory ShortVideoCandidateQualitySummary.emptySchema1() {
    return const ShortVideoCandidateQualitySummary(
      schemaVersion: 1,
      projectBadCaseTotal: 0,
      assemblyShotReviewTotal: 0,
      assemblyShotBadCaseCount: 0,
      assemblyShotsWithBadCase: 0,
      assemblyLateStageBadCaseCount: 0,
      badCasesByStage: <ShortVideoQualityStageBucket>[],
    );
  }
}

class ShortVideoQualityStageBucket {
  const ShortVideoQualityStageBucket({
    required this.stage,
    required this.badCaseCount,
  });

  final String stage;
  final int badCaseCount;

  factory ShortVideoQualityStageBucket.fromJson(Map<String, dynamic> json) {
    return ShortVideoQualityStageBucket(
      stage: json['stage'] as String? ?? '',
      badCaseCount: (json['bad_case_count'] as num).toInt(),
    );
  }
}

class ProjectShortVideoAssembly {
  const ProjectShortVideoAssembly({
    required this.schemaVersion,
    required this.projectDefaults,
    required this.effectiveShortVideoDefaults,
    required this.candidateQualitySummary,
    required this.scripts,
  });

  final int schemaVersion;
  final ShortVideoAssemblyProjectDefaults projectDefaults;
  final ShortVideoAssemblyEffectiveDefaults effectiveShortVideoDefaults;
  final ShortVideoCandidateQualitySummary candidateQualitySummary;
  final List<ShortVideoAssemblyScriptGroup> scripts;

  factory ProjectShortVideoAssembly.fromJson(Map<String, dynamic> json) {
    final raw = json['scripts'] as List<dynamic>? ?? const <dynamic>[];
    final pd = ShortVideoAssemblyProjectDefaults.fromJson(
      json['project_defaults'] as Map<String, dynamic>,
    );
    final effRaw = json['effective_short_video_defaults'];
    final cqRaw = json['candidate_quality_summary'];
    return ProjectShortVideoAssembly(
      schemaVersion: (json['schema_version'] as num).toInt(),
      projectDefaults: pd,
      effectiveShortVideoDefaults: effRaw is Map<String, dynamic>
          ? ShortVideoAssemblyEffectiveDefaults.fromJson(effRaw)
          : ShortVideoAssemblyEffectiveDefaults.inferredFromProjectDefaults(pd),
      candidateQualitySummary: cqRaw is Map<String, dynamic>
          ? ShortVideoCandidateQualitySummary.fromJson(cqRaw)
          : ShortVideoCandidateQualitySummary.emptySchema1(),
      scripts: raw
          .map(
            (e) => ShortVideoAssemblyScriptGroup.fromJson(
              e as Map<String, dynamic>,
            ),
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

/// Wave 6：按分镜聚合的导出缺口（**`GET …/short-video-export-check`** **`storyboard_gaps`**）。
class ShortVideoExportCheckStoryboardGap {
  const ShortVideoExportCheckStoryboardGap({
    required this.scriptNumericId,
    required this.storyboardId,
    required this.storyboardNumericId,
    this.sbIndex,
    required this.gapCodes,
    required this.hasBlocking,
    required this.missingSelectedVideo,
    required this.missingSubtitle,
    required this.missingVoiceover,
    required this.durationAnomaly,
  });

  final int scriptNumericId;
  final String storyboardId;
  final int storyboardNumericId;
  final int? sbIndex;
  final List<String> gapCodes;
  final bool hasBlocking;
  final bool missingSelectedVideo;
  final bool missingSubtitle;
  final bool missingVoiceover;
  final bool durationAnomaly;

  factory ShortVideoExportCheckStoryboardGap.fromJson(
    Map<String, dynamic> json,
  ) {
    final codes = json['gap_codes'] as List<dynamic>? ?? const <dynamic>[];
    return ShortVideoExportCheckStoryboardGap(
      scriptNumericId: (json['script_numeric_id'] as num).toInt(),
      storyboardId: json['storyboard_id'] as String,
      storyboardNumericId: (json['storyboard_numeric_id'] as num).toInt(),
      sbIndex: json['sb_index'] == null
          ? null
          : (json['sb_index'] as num).toInt(),
      gapCodes: codes.map((e) => e as String).toList(growable: false),
      hasBlocking: json['has_blocking'] as bool? ?? false,
      missingSelectedVideo: json['missing_selected_video'] as bool? ?? false,
      missingSubtitle: json['missing_subtitle'] as bool? ?? false,
      missingVoiceover: json['missing_voiceover'] as bool? ?? false,
      durationAnomaly: json['duration_anomaly'] as bool? ?? false,
    );
  }
}

class QualityGateBlockingReason {
  const QualityGateBlockingReason({
    required this.code,
    required this.message,
    this.reworkRoute,
  });

  final String code;
  final String message;
  final String? reworkRoute;

  factory QualityGateBlockingReason.fromJson(Map<String, dynamic> json) {
    return QualityGateBlockingReason(
      code: json['code'] as String,
      message: json['message'] as String,
      reworkRoute: json['rework_route'] as String?,
    );
  }
}

class ShortVideoExportQualityGate {
  const ShortVideoExportQualityGate({
    required this.schemaVersion,
    required this.strategy,
    required this.enforced,
    required this.pendingReviewBadCaseCount,
    this.blockingReasons,
  });

  final int schemaVersion;

  /// 门禁策略：off（跳过检查）、warn（显示警告但允许）、block（阻断导出）
  final String strategy;
  final bool enforced;
  final int pendingReviewBadCaseCount;
  final List<QualityGateBlockingReason>? blockingReasons;

  factory ShortVideoExportQualityGate.fromJson(Map<String, dynamic> json) {
    final blockingReasonsRaw = json['blocking_reasons'] as List<dynamic>?;
    return ShortVideoExportQualityGate(
      schemaVersion: (json['schema_version'] as num).toInt(),
      strategy: json['strategy'] as String,
      enforced: json['enforced'] as bool,
      pendingReviewBadCaseCount: (json['pending_review_bad_case_count'] as num)
          .toInt(),
      blockingReasons: blockingReasonsRaw
          ?.map(
            (e) =>
                QualityGateBlockingReason.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

/// Publish cover/platform facet on export-check (**`publish_facets`**).
class ShortVideoExportPublishFacets {
  const ShortVideoExportPublishFacets({
    required this.missingCover,
    required this.missingTargetPlatforms,
    this.platformFacets = const <ShortVideoExportPlatformFacet>[],
  });

  final bool missingCover;
  final bool missingTargetPlatforms;
  final List<ShortVideoExportPlatformFacet> platformFacets;

  factory ShortVideoExportPublishFacets.fromJson(Map<String, dynamic> json) {
    final facetsRaw =
        json['platform_facets'] as List<dynamic>? ?? const <dynamic>[];
    return ShortVideoExportPublishFacets(
      missingCover: json['missing_cover'] as bool? ?? false,
      missingTargetPlatforms:
          json['missing_target_platforms'] as bool? ?? false,
      platformFacets: facetsRaw
          .map(
            (e) => ShortVideoExportPlatformFacet.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class ShortVideoExportPlatformFacet {
  const ShortVideoExportPlatformFacet({
    required this.platformId,
    required this.missingCover,
    required this.missingPlatformCopy,
    required this.hasBlocking,
    required this.gapCodes,
  });

  final String platformId;
  final bool missingCover;
  final bool missingPlatformCopy;
  final bool hasBlocking;
  final List<String> gapCodes;

  factory ShortVideoExportPlatformFacet.fromJson(Map<String, dynamic> json) {
    final codes = json['gap_codes'] as List<dynamic>? ?? const <dynamic>[];
    return ShortVideoExportPlatformFacet(
      platformId: json['platform_id'] as String? ?? '',
      missingCover: json['missing_cover'] as bool? ?? false,
      missingPlatformCopy: json['missing_platform_copy'] as bool? ?? false,
      hasBlocking: json['has_blocking'] as bool? ?? false,
      gapCodes: codes.map((e) => e as String).toList(growable: false),
    );
  }
}

class ShortVideoExportPublishIssue {
  const ShortVideoExportPublishIssue({
    required this.severity,
    required this.code,
    required this.detail,
    this.platformId,
  });

  final String severity;
  final String code;
  final String detail;
  final String? platformId;

  factory ShortVideoExportPublishIssue.fromJson(Map<String, dynamic> json) {
    return ShortVideoExportPublishIssue(
      severity: json['severity'] as String? ?? 'warning',
      code: json['code'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      platformId: json['platform_id'] as String?,
    );
  }
}

class ProjectShortVideoExportCheck {
  const ProjectShortVideoExportCheck({
    required this.schemaVersion,
    this.dataVersion,
    required this.exportReady,
    required this.summary,
    required this.issues,
    this.storyboardGaps = const <ShortVideoExportCheckStoryboardGap>[],
    this.publishFacets = const ShortVideoExportPublishFacets(
      missingCover: false,
      missingTargetPlatforms: false,
    ),
    this.publishIssues = const <ShortVideoExportPublishIssue>[],
    required this.qualityGate,
  });

  final int schemaVersion;
  final String? dataVersion;
  final bool exportReady;
  final ShortVideoExportCheckSummary summary;
  final List<ShortVideoExportCheckIssue> issues;
  final List<ShortVideoExportCheckStoryboardGap> storyboardGaps;
  final ShortVideoExportPublishFacets publishFacets;
  final List<ShortVideoExportPublishIssue> publishIssues;
  final ShortVideoExportQualityGate qualityGate;

  factory ProjectShortVideoExportCheck.fromJson(Map<String, dynamic> json) {
    final raw = json['issues'] as List<dynamic>? ?? const <dynamic>[];
    final gapsRaw =
        json['storyboard_gaps'] as List<dynamic>? ?? const <dynamic>[];
    final publishRaw =
        json['publish_issues'] as List<dynamic>? ?? const <dynamic>[];
    final publishFacetsRaw = json['publish_facets'];
    final qgRaw = json['quality_gate'];
    return ProjectShortVideoExportCheck(
      schemaVersion: (json['schema_version'] as num).toInt(),
      dataVersion: json['data_version'] as String?,
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
      storyboardGaps: gapsRaw
          .map(
            (e) => ShortVideoExportCheckStoryboardGap.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      publishFacets: publishFacetsRaw is Map<String, dynamic>
          ? ShortVideoExportPublishFacets.fromJson(publishFacetsRaw)
          : const ShortVideoExportPublishFacets(
              missingCover: false,
              missingTargetPlatforms: false,
            ),
      publishIssues: publishRaw
          .map(
            (e) => ShortVideoExportPublishIssue.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      qualityGate: qgRaw is Map<String, dynamic>
          ? ShortVideoExportQualityGate.fromJson(qgRaw)
          : const ShortVideoExportQualityGate(
              schemaVersion: 1,
              strategy: 'off',
              enforced: false,
              pendingReviewBadCaseCount: 0,
            ),
    );
  }
}
