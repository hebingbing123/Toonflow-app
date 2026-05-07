// Project overview data models - Part 2: Assets, assembly, and export models

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
      pendingReviewBadCaseCount: (json['pending_review_bad_case_count'] as num)
          .toInt(),
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

