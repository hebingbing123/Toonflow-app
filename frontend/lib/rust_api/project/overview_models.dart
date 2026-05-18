// Project overview data models - Part 1: Core project and readiness models

class ProjectRow {
  const ProjectRow({
    required this.id,
    this.workspaceId,
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
    required this.projectAccessMode,
    required this.projectAccessRole,
  });

  final String id;
  final String? workspaceId;
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
  final String projectAccessMode;
  final String projectAccessRole;

  factory ProjectRow.fromJson(Map<String, dynamic> json) {
    List<String>? platforms;
    final tp = json['target_platforms'];
    if (tp is List<dynamic>) {
      platforms = tp.map((e) => e.toString()).toList(growable: false);
    }
    return ProjectRow(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String?,
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
      projectAccessMode: json['project_access_mode'] as String? ?? 'inherited',
      projectAccessRole: json['project_access_role'] as String? ?? 'member',
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

class ProjectBriefDraft {
  const ProjectBriefDraft({
    this.premise = '',
    this.targetAudience = '',
    this.emotionalTone = '',
    this.coreHook = '',
    this.visualDirection = '',
  });

  final String premise;
  final String targetAudience;
  final String emotionalTone;
  final String coreHook;
  final String visualDirection;

  factory ProjectBriefDraft.fromJson(Map<String, dynamic> json) {
    return ProjectBriefDraft(
      premise: json['premise'] as String? ?? '',
      targetAudience: json['targetAudience'] as String? ?? '',
      emotionalTone: json['emotionalTone'] as String? ?? '',
      coreHook: json['coreHook'] as String? ?? '',
      visualDirection: json['visualDirection'] as String? ?? '',
    );
  }

  Map<String, dynamic>? toJsonOrNull() {
    final map = <String, dynamic>{};
    if (premise.trim().isNotEmpty) map['premise'] = premise.trim();
    if (targetAudience.trim().isNotEmpty) {
      map['targetAudience'] = targetAudience.trim();
    }
    if (emotionalTone.trim().isNotEmpty) {
      map['emotionalTone'] = emotionalTone.trim();
    }
    if (coreHook.trim().isNotEmpty) map['coreHook'] = coreHook.trim();
    if (visualDirection.trim().isNotEmpty) {
      map['visualDirection'] = visualDirection.trim();
    }
    return map.isEmpty ? null : map;
  }
}

class BrandBibleDraft {
  const BrandBibleDraft({
    this.brandName = '',
    this.brandPromise = '',
    this.visualMotifs = const <String>[],
    this.forbiddenElements = const <String>[],
    this.continuityRules = const <String>[],
  });

  final String brandName;
  final String brandPromise;
  final List<String> visualMotifs;
  final List<String> forbiddenElements;
  final List<String> continuityRules;

  factory BrandBibleDraft.fromJson(Map<String, dynamic> json) {
    List<String> parseList(String key) {
      final raw = json[key] as List<dynamic>? ?? const <dynamic>[];
      return raw.map((item) => item.toString()).toList(growable: false);
    }

    return BrandBibleDraft(
      brandName: json['brandName'] as String? ?? '',
      brandPromise: json['brandPromise'] as String? ?? '',
      visualMotifs: parseList('visualMotifs'),
      forbiddenElements: parseList('forbiddenElements'),
      continuityRules: parseList('continuityRules'),
    );
  }

  Map<String, dynamic>? toJsonOrNull() {
    final map = <String, dynamic>{};
    if (brandName.trim().isNotEmpty) map['brandName'] = brandName.trim();
    if (brandPromise.trim().isNotEmpty) {
      map['brandPromise'] = brandPromise.trim();
    }
    if (visualMotifs.isNotEmpty) map['visualMotifs'] = visualMotifs;
    if (forbiddenElements.isNotEmpty) {
      map['forbiddenElements'] = forbiddenElements;
    }
    if (continuityRules.isNotEmpty) map['continuityRules'] = continuityRules;
    return map.isEmpty ? null : map;
  }
}

class ProjectHomeChecklistItem {
  const ProjectHomeChecklistItem({
    required this.key,
    required this.label,
    required this.done,
    this.detail,
  });

  final String key;
  final String label;
  final bool done;
  final String? detail;

  factory ProjectHomeChecklistItem.fromJson(Map<String, dynamic> json) {
    return ProjectHomeChecklistItem(
      key: json['key'] as String,
      label: json['label'] as String,
      done: json['done'] as bool,
      detail: json['detail'] as String?,
    );
  }
}

class ProjectHomeOnboarding {
  const ProjectHomeOnboarding({
    required this.complete,
    this.nextStep,
    required this.checklist,
  });

  final bool complete;
  final String? nextStep;
  final List<ProjectHomeChecklistItem> checklist;

  factory ProjectHomeOnboarding.fromJson(Map<String, dynamic> json) {
    final raw = json['checklist'] as List<dynamic>? ?? const <dynamic>[];
    return ProjectHomeOnboarding(
      complete: json['complete'] as bool? ?? false,
      nextStep: json['next_step'] as String?,
      checklist: raw
          .map(
            (item) =>
                ProjectHomeChecklistItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

class ProjectHomeAction {
  const ProjectHomeAction({
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

  factory ProjectHomeAction.fromJson(Map<String, dynamic> json) {
    return ProjectHomeAction(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      targetStep: json['target_step'] as String? ?? 'script',
      ctaLabel: json['cta_label'] as String? ?? '',
      launchIntent: ProjectHomeLaunchIntent.parseRequired(
        json['launch_intent'],
        context: 'ProjectHomeAction',
      ),
    );
  }
}

class ProjectHomeMetric {
  const ProjectHomeMetric({
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

  factory ProjectHomeMetric.fromJson(Map<String, dynamic> json) {
    return ProjectHomeMetric(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      launchIntent: ProjectHomeLaunchIntent.parseRequired(
        json['launch_intent'],
        context: 'ProjectHomeMetric',
      ),
    );
  }
}

class ProjectHomeStarterTemplate {
  const ProjectHomeStarterTemplate({
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

  factory ProjectHomeStarterTemplate.fromJson(Map<String, dynamic> json) {
    return ProjectHomeStarterTemplate(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      targetStep: json['target_step'] as String? ?? 'script',
      ctaLabel: json['cta_label'] as String? ?? '',
      launchIntent: ProjectHomeLaunchIntent.parseRequired(
        json['launch_intent'],
        context: 'ProjectHomeStarterTemplate',
      ),
    );
  }
}

class ProjectHomeLaunchIntent {
  const ProjectHomeLaunchIntent({
    this.targetStep,
    this.agentKind,
    this.assetTarget,
    this.action,
    this.notice,
  });

  final String? targetStep;
  final String? agentKind;
  final String? assetTarget;
  final String? action;
  final String? notice;

  bool get hasRoute {
    return (targetStep ?? '').trim().isNotEmpty ||
        (agentKind ?? '').trim().isNotEmpty ||
        (assetTarget ?? '').trim().isNotEmpty ||
        (action ?? '').trim().isNotEmpty;
  }

  factory ProjectHomeLaunchIntent.fromJson(Map<String, dynamic> raw) {
    final targetStep =
        raw['target_step'] as String? ?? raw['targetStep'] as String?;
    final agentKind =
        raw['agent_kind'] as String? ?? raw['agentKind'] as String?;
    final assetTarget =
        raw['asset_target'] as String? ?? raw['assetTarget'] as String?;
    final action = raw['action'] as String?;
    final notice = raw['notice'] as String?;
    final intent = ProjectHomeLaunchIntent(
      targetStep: targetStep,
      agentKind: agentKind,
      assetTarget: assetTarget,
      action: action,
      notice: notice,
    );
    if (!intent.hasRoute) {
      throw const FormatException(
        'launch_intent must include action, target_step, agent_kind, or asset_target',
      );
    }
    return intent;
  }

  static ProjectHomeLaunchIntent parseRequired(
    Object? raw, {
    required String context,
  }) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException('$context.launch_intent must be a JSON object');
    }
    try {
      return ProjectHomeLaunchIntent.fromJson(raw);
    } on FormatException catch (error) {
      throw FormatException('$context.${error.message}');
    }
  }
}

class ProjectHomeCockpit {
  const ProjectHomeCockpit({
    required this.headline,
    required this.subheadline,
    required this.primaryAction,
    required this.secondaryActions,
    required this.metrics,
    required this.starterTemplates,
  });

  final String headline;
  final String subheadline;
  final ProjectHomeAction primaryAction;
  final List<ProjectHomeAction> secondaryActions;
  final List<ProjectHomeMetric> metrics;
  final List<ProjectHomeStarterTemplate> starterTemplates;

  factory ProjectHomeCockpit.fromJson(Map<String, dynamic> json) {
    final secondary =
        json['secondary_actions'] as List<dynamic>? ?? const <dynamic>[];
    final metrics = json['metrics'] as List<dynamic>? ?? const <dynamic>[];
    final starters =
        json['starter_templates'] as List<dynamic>? ?? const <dynamic>[];
    return ProjectHomeCockpit(
      headline: json['headline'] as String? ?? '',
      subheadline: json['subheadline'] as String? ?? '',
      primaryAction: ProjectHomeAction.fromJson(
        json['primary_action'] as Map<String, dynamic>,
      ),
      secondaryActions: secondary
          .map(
            (item) => ProjectHomeAction.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      metrics: metrics
          .map(
            (item) => ProjectHomeMetric.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      starterTemplates: starters
          .map(
            (item) => ProjectHomeStarterTemplate.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class ProjectHome {
  const ProjectHome({
    required this.project,
    required this.stats,
    required this.readinessScore,
    required this.readinessSummary,
    required this.onboarding,
    required this.styleBibleReady,
    required this.cockpit,
    this.projectBrief,
    this.brandBible,
  });

  final ProjectRow project;
  final ProjectStats stats;
  final int readinessScore;
  final String readinessSummary;
  final ProjectHomeOnboarding onboarding;
  final bool styleBibleReady;
  final ProjectHomeCockpit cockpit;
  final ProjectBriefDraft? projectBrief;
  final BrandBibleDraft? brandBible;

  factory ProjectHome.fromJson(Map<String, dynamic> json) {
    return ProjectHome(
      project: ProjectRow.fromJson(json['project'] as Map<String, dynamic>),
      stats: ProjectStats.fromJson(json['stats'] as Map<String, dynamic>),
      readinessScore: (json['readiness_score'] as num).toInt(),
      readinessSummary: json['readiness_summary'] as String? ?? '',
      onboarding: ProjectHomeOnboarding.fromJson(
        json['onboarding'] as Map<String, dynamic>,
      ),
      styleBibleReady: json['style_bible_ready'] as bool? ?? false,
      cockpit: ProjectHomeCockpit.fromJson(
        json['cockpit'] as Map<String, dynamic>,
      ),
      projectBrief: json['project_brief'] is Map<String, dynamic>
          ? ProjectBriefDraft.fromJson(
              json['project_brief'] as Map<String, dynamic>,
            )
          : null,
      brandBible: json['brand_bible'] is Map<String, dynamic>
          ? BrandBibleDraft.fromJson(
              json['brand_bible'] as Map<String, dynamic>,
            )
          : null,
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
    required this.hasLiveActionReferenceShots,
    required this.hasLiveActionPerformanceNotes,
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
  final bool hasLiveActionReferenceShots;
  final bool hasLiveActionPerformanceNotes;
  final bool candidateCleared;
  final bool noBlockingJob;
  final bool readyForGeneration;
  final List<String> blockingReasons;

  factory StoryboardShortVideoReadiness.fromJson(Map<String, dynamic> json) {
    final reasons =
        json['blocking_reasons'] as List<dynamic>? ?? const <dynamic>[];
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
      hasLiveActionReferenceShots:
          json['has_live_action_reference_shots'] as bool? ?? false,
      hasLiveActionPerformanceNotes:
          json['has_live_action_performance_notes'] as bool? ?? false,
      candidateCleared: json['candidate_cleared'] as bool,
      noBlockingJob: json['no_blocking_job'] as bool,
      readyForGeneration: json['ready_for_generation'] as bool,
      blockingReasons: reasons
          .map(_parseShortVideoBlockingReasonFromJson)
          .toList(),
    );
  }
}

String _parseShortVideoBlockingReasonFromJson(dynamic e) {
  if (e is String) {
    return e.trim();
  }
  if (e is Map) {
    final m = Map<String, dynamic>.from(e);
    final c = m['code'] ?? m['reason'] ?? m['kind'];
    if (c is String) {
      return c.trim();
    }
  }
  return e.toString();
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
      runningGenerationJobCount: (json['running_generation_job_count'] as num)
          .toInt(),
      pendingReviewBadCaseCount: (json['pending_review_bad_case_count'] as num)
          .toInt(),
    );
  }
}

/// `GET /api/v1/projects/{project_id}/assets-overview` — see `getProjectAssetsOverviewByProjectIdV1`.
