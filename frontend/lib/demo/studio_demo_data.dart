import '../debug/project_studio_script_debug_preview.dart';
import '../l10n/app_localizations.dart';
import '../project_editor/style_pack_catalog.dart';
import '../project_studio/studio_readiness.dart';
import '../rust_api.dart';

const demoStudioProjectUuid = '00000000-0000-0000-0000-000000000007';

ProjectHome buildDemoStudioProjectHome(AppLocalizations l10n) {
  final projectName = l10n.demoStudioProjectDisplayName;
  return ProjectHome(
    project: ProjectRow(
      id: demoStudioProjectUuid,
      numericId: 7,
      name: projectName,
      artStylePack: 'art_skills/2D_chinese_guofeng',
      storyStylePack: 'story_skills/Family_warmth',
      artStyle: l10n.demoStudioArtStyleInkWash,
      projectAccessMode: 'inherited',
      projectAccessRole: 'owner',
    ),
    stats: const ProjectStats(
      scriptCount: 2,
      storyboardCount: 6,
      roleCount: 3,
      novelCount: 1,
      videoCount: 0,
    ),
    readinessScore: 68,
    readinessSummary: l10n.demoStudioReadinessSummary,
    onboarding: ProjectHomeOnboarding(
      complete: false,
      checklist: <ProjectHomeChecklistItem>[
        ProjectHomeChecklistItem(
          key: 'script',
          label: l10n.demoStudioChecklistScriptLabel,
          done: true,
        ),
        ProjectHomeChecklistItem(
          key: 'storyboard',
          label: l10n.demoStudioChecklistStoryboardLabel,
          done: false,
        ),
      ],
    ),
    styleBibleReady: true,
    cockpit: ProjectHomeCockpit(
      headline: projectName,
      subheadline: l10n.demoStudioHomeSubheadline,
      primaryAction: ProjectHomeAction(
        key: 'continue_storyboard',
        title: l10n.demoStudioHomeContinueStoryboardTitle,
        detail: l10n.demoStudioHomeContinueStoryboardDetail,
        targetStep: 'storyboard',
        ctaLabel: l10n.demoStudioHomeOpenStoryboardCta,
        launchIntent: const ProjectHomeLaunchIntent(targetStep: 'storyboard'),
      ),
      secondaryActions: <ProjectHomeAction>[
        ProjectHomeAction(
          key: 'open_tasks',
          title: l10n.demoStudioHomeOpenTasksTitle,
          detail: l10n.demoStudioHomeTasksDetail,
          targetStep: 'tasks',
          ctaLabel: l10n.demoStudioHomeTasksCta,
          launchIntent: const ProjectHomeLaunchIntent(action: 'open_tasks'),
        ),
      ],
      metrics: <ProjectHomeMetric>[
        ProjectHomeMetric(
          key: 'content',
          label: l10n.demoStudioMetricContentLabel,
          value: l10n.demoStudioMetricContentValue,
          detail: l10n.demoStudioMetricContentDetail,
        ),
        ProjectHomeMetric(
          key: 'storyboard',
          label: l10n.demoStudioMetricStoryboardLabel,
          value: l10n.demoStudioMetricStoryboardValue,
          detail: l10n.demoStudioMetricStoryboardDetail,
          launchIntent: const ProjectHomeLaunchIntent(targetStep: 'storyboard'),
        ),
      ],
      starterTemplates: const <ProjectHomeStarterTemplate>[],
    ),
  );
}

ProjectAssetsOverview buildDemoStudioAssetsOverview(AppLocalizations l10n) {
  final leadName = l10n.demoStudioCharacterLeadName;
  return ProjectAssetsOverview(
    schemaVersion: 1,
    totalCount: 4,
    candidateCounts: AssetsOverviewCandidateCounts(
      pending: 1,
      linked: 2,
      ignored: 0,
      unset: 1,
    ),
    byAssetType: <AssetsOverviewTypeGroup>[],
    hub: AssetsOverviewHub(
      headline: l10n.demoStudioAssetsHubHeadline,
      subheadline: l10n.demoStudioAssetsHubSubheadline,
      primaryAction: AssetsOverviewHubAction(
        key: 'anchor_characters',
        title: l10n.demoStudioAssetsAnchorTitle,
        detail: l10n.demoStudioAssetsAnchorDetail(leadName),
        targetStep: 'assets',
        ctaLabel: l10n.demoStudioAssetsOpenAssetsCta,
      ),
      metrics: <AssetsOverviewHubMetric>[
        AssetsOverviewHubMetric(
          key: 'roles',
          label: l10n.demoStudioAssetsRolesLabel,
          value: '3',
          detail: l10n.demoStudioAssetsPendingAnchorsCountDetail(1),
        ),
      ],
      characterSummaries: <AssetsOverviewCharacterSummary>[
        AssetsOverviewCharacterSummary(
          characterId: 'char-lead',
          name: leadName,
          assetId: null,
          assetName: null,
          linkedScriptNumericIds: <int>[3],
          hasVoiceConfig: false,
          missingAssetAnchor: true,
        ),
      ],
      reusableRoleAssets: <AssetsOverviewRoleSummary>[
        AssetsOverviewRoleSummary(
          assetId: 'asset-lead',
          numericId: 71,
          name: l10n.demoStudioCharacterLeadAssetName,
          candidateStatus: 'linked',
          linkedScriptNumericIds: <int>[3],
          linkedCharacterNames: <String>[leadName],
        ),
      ],
    ),
  );
}

ProjectShortVideoReadiness buildDemoStudioShortVideoReadiness() {
  return ProjectShortVideoReadiness.fromJson(<String, dynamic>{
    'schema_version': 1,
    'rollup': <String, dynamic>{
      'total_storyboards': 6,
      'ready_count': 4,
      'blocked_count': 1,
      'by_reason': <dynamic>[],
    },
    'storyboards': <Map<String, dynamic>>[
      <String, dynamic>{
        'storyboard_id': 'sb-demo-101',
        'storyboard_numeric_id': 101,
        'script_numeric_id': 3,
        'sb_index': 1,
        'has_basic_slot': true,
        'has_prompt_context': true,
        'has_reference_visual': true,
        'candidate_cleared': true,
        'no_blocking_job': true,
        'ready_for_generation': true,
        'blocking_reasons': <dynamic>[],
      },
      <String, dynamic>{
        'storyboard_id': 'sb-demo-102',
        'storyboard_numeric_id': 102,
        'script_numeric_id': 3,
        'sb_index': 2,
        'has_basic_slot': true,
        'has_prompt_context': true,
        'has_reference_visual': false,
        'candidate_cleared': true,
        'no_blocking_job': true,
        'ready_for_generation': false,
        'blocking_reasons': <String>['missing_reference_visual'],
      },
      <String, dynamic>{
        'storyboard_id': 'sb-demo-103',
        'storyboard_numeric_id': 103,
        'script_numeric_id': 3,
        'sb_index': 3,
        'has_basic_slot': true,
        'has_prompt_context': true,
        'has_reference_visual': true,
        'candidate_cleared': true,
        'no_blocking_job': true,
        'ready_for_generation': true,
        'blocking_reasons': <dynamic>[],
      },
    ],
  });
}

ProjectShortVideoAssembly buildDemoStudioShortVideoAssembly() {
  final l10n = rustApiLookupL10nFromPlatform();
  return ProjectShortVideoAssembly.fromJson(<String, dynamic>{
    'schema_version': 1,
    'project_defaults': <String, dynamic>{
      'voice_profile': 'nova',
      'subtitle_style': 'bottom_caption',
      'bgm_strategy': 'light_piano',
    },
    'candidate_quality_summary': <String, dynamic>{
      'schema_version': 1,
      'project_bad_case_total': 1,
      'assembly_shot_review_total': 3,
      'assembly_shot_bad_case_count': 0,
      'assembly_shots_with_bad_case': 0,
      'assembly_late_stage_bad_case_count': 0,
      'bad_cases_by_stage': <dynamic>[],
    },
    'scripts': <Map<String, dynamic>>[
      <String, dynamic>{
        'script_numeric_id': 3,
        'script_name': l10n.demoScriptEpisode1Name,
        'shots': <Map<String, dynamic>>[
          _demoAssemblyShotJson(
            l10n: l10n,
            storyboardId: 'sb-demo-101',
            storyboardNumericId: 101,
            sbIndex: 1,
            ready: true,
          ),
          _demoAssemblyShotJson(
            l10n: l10n,
            storyboardId: 'sb-demo-102',
            storyboardNumericId: 102,
            sbIndex: 2,
            ready: false,
          ),
          _demoAssemblyShotJson(
            l10n: l10n,
            storyboardId: 'sb-demo-103',
            storyboardNumericId: 103,
            sbIndex: 3,
            ready: true,
          ),
        ],
      },
    ],
  });
}

Map<String, dynamic> _demoAssemblyShotJson({
  required AppLocalizations l10n,
  required String storyboardId,
  required int storyboardNumericId,
  required int sbIndex,
  required bool ready,
}) {
  return <String, dynamic>{
    'storyboard_id': storyboardId,
    'storyboard_numeric_id': storyboardNumericId,
    'sb_index': sbIndex,
    'selected_media_url': ready ? 'https://demo.openflow/clip-$storyboardNumericId.mp4' : null,
    'selected_media_kind': ready ? 'video' : 'none',
    'duration': '3.2s',
    'state': ready ? 'ready' : 'draft',
    'subtitle_text': ready ? l10n.demoAssemblySubtitleTemplate(sbIndex) : null,
    'subtitle_source': ready ? 'storyboard' : 'none',
    'voiceover_script_ready': ready,
    'voiceover_state': ready ? 'ready' : 'pending',
    'voiceover_audio_url': ready ? 'https://demo.openflow/vo-$storyboardNumericId.mp3' : null,
    'voiceover_asset_ready': ready,
    'export_gap': <String, dynamic>{
      'gap_codes': ready ? <dynamic>[] : <String>['missing_selected_video'],
      'has_blocking': !ready,
      'missing_selected_video': !ready,
      'missing_subtitle': false,
      'missing_voiceover': false,
      'duration_anomaly': false,
    },
  };
}

ProjectShortVideoExportCheck buildDemoStudioShortVideoExportCheck() {
  return ProjectShortVideoExportCheck.fromJson(<String, dynamic>{
    'schema_version': 1,
    'data_version': 'demo-v1',
    'export_ready': true,
    'summary': <String, dynamic>{
      'storyboard_count': 3,
      'blocking_issue_count': 0,
      'warning_issue_count': 1,
    },
    'issues': <dynamic>[],
    'storyboard_gaps': <dynamic>[],
    'publish_facets': <String, dynamic>{
      'missing_cover': false,
      'missing_target_platforms': false,
    },
    'publish_issues': <dynamic>[],
    'quality_gate': <String, dynamic>{
      'schema_version': 1,
      'strategy': 'warn',
      'enforced': false,
      'pending_review_bad_case_count': 1,
      'blocking_reasons': <dynamic>[],
    },
  });
}

ProjectShortVideoTimelineV1 buildDemoStudioShortVideoTimeline() {
  final l10n = rustApiLookupL10nFromPlatform();
  return ProjectShortVideoTimelineV1.fromJson(<String, dynamic>{
    'schemaVersion': 1,
    'timelineVersion': 'demo-timeline-v1',
    'revision': 1,
    'tracks': <String, dynamic>{
      'video': <Map<String, dynamic>>[
        <String, dynamic>{
          'storyboardNumericId': 101,
          'inMs': 0,
          'outMs': 3200,
          'sourceUrl': 'https://demo.openflow/clip-101.mp4',
        },
        <String, dynamic>{
          'storyboardNumericId': 103,
          'inMs': 3200,
          'outMs': 6000,
          'sourceUrl': 'https://demo.openflow/clip-103.mp4',
        },
      ],
      'subtitles': <Map<String, dynamic>>[
        <String, dynamic>{
          'storyboardNumericId': 101,
          'startMs': 0,
          'endMs': 3200,
          'text': l10n.demoTimelineSubtitleRainStreet,
        },
      ],
    },
    'scripts': <Map<String, dynamic>>[
      <String, dynamic>{
        'scriptNumericId': 3,
        'scriptName': l10n.demoScriptEpisode1Name,
        'shots': <dynamic>[],
      },
    ],
  });
}

TaskCenterGetTaskApiResult buildDemoRecentProjectTasks() {
  return TaskCenterGetTaskApiResult(
    data: <JobRow>[
      JobRow(
        numericTaskId: 101,
        id: 'job-101',
        ownerUserId: 'demo-user',
        kind: 'asset.generate.image',
        status: 'running',
        payload: <String, dynamic>{'project_numeric_id': 7},
        createdAt: '2026-04-10T00:00:00Z',
        updatedAt: '2026-04-10T00:01:00Z',
      ),
      JobRow(
        numericTaskId: 102,
        id: 'job-102',
        ownerUserId: 'demo-user',
        kind: 'video.export',
        status: 'queued',
        payload: <String, dynamic>{'project_numeric_id': 7},
        createdAt: '2026-04-10T00:02:00Z',
        updatedAt: '2026-04-10T00:03:00Z',
      ),
    ],
    total: 2,
  );
}

ProjectDetail buildDemoProjectDetail() {
  final l10n = rustApiLookupL10nFromPlatform();
  return ProjectDetail(
    project: ProjectRow(
      id: demoStudioProjectUuid,
      numericId: 7,
      name: l10n.demoStudioProjectDisplayName,
      artStylePack: 'art_skills/2D_chinese_guofeng',
      storyStylePack: 'story_skills/Family_warmth',
      artStyle: l10n.demoStudioArtStyleInkWash,
      projectAccessMode: 'inherited',
      projectAccessRole: 'owner',
    ),
    scripts: <ScriptBrief>[
      ScriptBrief(
        numericId: 3,
        name: l10n.demoScriptEpisode1Name,
        extractState: 1,
      ),
      ScriptBrief(
        numericId: 4,
        name: l10n.demoScriptEpisode2Name,
        extractState: 0,
      ),
    ],
  );
}

ListAssetsResponse buildDemoProjectAssetsList() {
  final l10n = rustApiLookupL10nFromPlatform();
  return ListAssetsResponse(
    total: 3,
    items: <AssetRow>[
      AssetRow(
        id: 'asset-lead',
        numericId: 71,
        name: l10n.demoAssetLeadLookName,
        assetType: 'role',
        description: l10n.demoAssetLeadLookDescription,
        candidateStatus: 'linked',
      ),
      AssetRow(
        id: 'asset-scene-1',
        numericId: 72,
        name: l10n.demoAssetRainyStreetName,
        assetType: 'scene',
        description: l10n.demoAssetRainyStreetDescription,
        candidateStatus: 'linked',
      ),
      AssetRow(
        id: 'asset-pending',
        numericId: 73,
        name: l10n.demoAssetCafeInteriorName,
        assetType: 'scene',
        description: l10n.demoAssetCafeInteriorDescription,
        candidateStatus: 'pending',
      ),
    ],
  );
}

ProjectModelRoutingResponse buildDemoProjectModelRouting() {
  return ProjectModelRoutingResponse(
    projectId: demoStudioProjectUuid,
    defaults: const ProjectModelRoutingDefaults(
      textModel: 'gpt-4o-mini',
      imageModel: 'flux-demo',
      videoModel: 'kling-demo',
    ),
    steps: <String, Map<String, String>>{
      'script': <String, String>{'text': 'gpt-4o-mini'},
      'storyboard': <String, String>{'image': 'flux-demo'},
      'video': <String, String>{'video': 'kling-demo'},
    },
    effective: const <ModelRoutingEffectiveEntry>[
      ModelRoutingEffectiveEntry(
        step: 'script',
        slot: 'text',
        modelId: 'gpt-4o-mini',
        source: 'project_default',
      ),
      ModelRoutingEffectiveEntry(
        step: 'storyboard',
        slot: 'image',
        modelId: 'flux-demo',
        source: 'step_override',
      ),
    ],
  );
}

ProjectProductionOverview buildDemoStudioProductionOverview() {
  return ProjectProductionOverview.fromJson(<String, dynamic>{
    'schema_version': 1,
    'total_storyboard_count': 6,
    'ready_storyboard_count': 4,
    'running_generation_job_count': 1,
    'pending_review_bad_case_count': 1,
  });
}

StylePackCatalog buildDemoStylePackCatalog(AppLocalizations l10n) {
  return StylePackCatalog(
    artPacks: <StylePackOption>[
      StylePackOption(
        path: 'art_skills/2D_chinese_guofeng',
        name: l10n.demoStudioArtStyleInkWash,
        description: l10n.projectEditorStylePackTagArt,
        tag: l10n.projectEditorStylePackTagArt,
      ),
    ],
    storyPacks: <StylePackOption>[
      StylePackOption(
        path: 'story_skills/Family_warmth',
        name: l10n.demoStylePackFamilyWarmthName,
        description: l10n.projectEditorStylePackTagStory,
        tag: l10n.projectEditorStylePackTagStory,
      ),
    ],
  );
}

Future<StudioReadinessSnapshot> buildDemoStudioReadinessSnapshot(
  String accessToken,
  String projectUuid,
) async {
  final l10n = rustApiLookupL10nFromPlatform();
  return StudioReadinessSnapshot(
    completedSteps: 5,
    runningJobCount: 0,
    failedJobCount: 0,
    home: buildDemoStudioProjectHome(l10n),
    assetsOverview: buildDemoStudioAssetsOverview(l10n),
    readiness: buildDemoStudioShortVideoReadiness(),
    production: buildDemoStudioProductionOverview(),
  );
}

Future<ProjectStudioScriptStepDebugContent> buildDemoScriptStepContent(
  String accessToken,
  String projectUuid,
) async {
  final l10n = rustApiLookupL10nFromPlatform();
  return ProjectStudioScriptStepDebugContent(
    novels: ListNovelsResponse(
      total: 1,
      items: <NovelRow>[
        NovelRow(
          id: 'novel-demo-1',
          numericId: 501,
          chapterIndex: 1,
          chapter: l10n.demoNovelChapter1Title,
          chapterData: l10n.demoNovelChapter1Body,
          eventState: 0,
          intakeSource: 'paste',
          intakeStatus: 'ready',
        ),
      ],
    ),
    scripts: <ScriptBrief>[
      ScriptBrief(
        numericId: 3,
        name: l10n.demoScriptEpisode1Name,
        extractState: 1,
      ),
      ScriptBrief(
        numericId: 4,
        name: l10n.demoScriptEpisode2Name,
        extractState: 0,
      ),
    ],
    stats: const ProjectStats(
      scriptCount: 2,
      storyboardCount: 6,
      roleCount: 3,
      novelCount: 1,
      videoCount: 0,
    ),
  );
}

List<PublishDraftRow> buildDemoPublishDrafts(AppLocalizations l10n) {
  return <PublishDraftRow>[
    PublishDraftRow(
      id: 'draft-demo-1',
      projectId: demoStudioProjectUuid,
      title: l10n.demoPublishDraftEpisode1Title,
      description: l10n.demoPublishDraft1Description,
      tags: <String>[l10n.demoPublishTagShortDrama, l10n.demoPublishTagUrban],
      draftStatus: 'ready',
      scriptId: '3',
      scheduledAt: '2026-05-20T10:00:00Z',
    ),
    PublishDraftRow(
      id: 'draft-demo-2',
      projectId: demoStudioProjectUuid,
      title: l10n.demoPublishDraftEpisode2Title,
      description: l10n.demoPublishDraft2Description,
      tags: <String>[l10n.demoPublishTagShortDrama],
      draftStatus: 'draft',
      scriptId: '4',
    ),
  ];
}

List<ScriptWorkbenchDetailRow> buildDemoStoryboardScripts() {
  final l10n = rustApiLookupL10nFromPlatform();
  return <ScriptWorkbenchDetailRow>[
    ScriptWorkbenchDetailRow(
      numericId: 3,
      name: l10n.demoScriptEpisode1Name,
      relatedAssets: <ScriptRelatedAssetBrief>[],
    ),
    ScriptWorkbenchDetailRow(
      numericId: 4,
      name: l10n.demoScriptEpisode2Name,
      relatedAssets: <ScriptRelatedAssetBrief>[],
    ),
  ];
}

List<ProductionStoryboardItemV1> buildDemoStoryboardShots() {
  final l10n = rustApiLookupL10nFromPlatform();
  return <ProductionStoryboardItemV1>[
    ProductionStoryboardItemV1(
      id: 101,
      scriptId: 3,
      prompt: l10n.demoStoryboardPromptRainStreet,
      state: 'ready',
      sbIndex: 1,
    ),
    ProductionStoryboardItemV1(
      id: 102,
      scriptId: 3,
      prompt: l10n.demoStoryboardPromptMaleCloseup,
      state: 'draft',
      sbIndex: 2,
    ),
    ProductionStoryboardItemV1(
      id: 103,
      scriptId: 3,
      prompt: l10n.demoStoryboardPromptDuoResolve,
      state: 'draft',
      sbIndex: 3,
    ),
  ];
}
