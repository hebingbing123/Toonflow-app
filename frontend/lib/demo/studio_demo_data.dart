import '../debug/project_studio_script_debug_preview.dart';
import '../l10n/app_localizations.dart';
import '../project_editor/style_pack_catalog.dart';
import '../project_studio/studio_readiness.dart';
import '../rust_api.dart';

const demoStudioProjectUuid = '00000000-0000-0000-0000-000000000007';

ProjectHome buildDemoStudioProjectHome() {
  return ProjectHome(
    project: ProjectRow(
      id: demoStudioProjectUuid,
      numericId: 7,
      name: '春季短剧 · 演示',
      artStylePack: 'art_skills/2D_chinese_guofeng',
      storyStylePack: 'story_skills/Family_warmth',
      artStyle: '水墨古风',
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
    readinessSummary: '剧本与分镜进度良好，待补齐成片素材',
    onboarding: const ProjectHomeOnboarding(
      complete: false,
      checklist: <ProjectHomeChecklistItem>[
        ProjectHomeChecklistItem(
          key: 'script',
          label: '导入或创建剧本',
          done: true,
        ),
        ProjectHomeChecklistItem(
          key: 'storyboard',
          label: '完成分镜',
          done: false,
        ),
      ],
    ),
    styleBibleReady: true,
    cockpit: ProjectHomeCockpit(
      headline: '春季短剧 · 演示',
      subheadline: '小说 1 / 剧本 2',
      primaryAction: ProjectHomeAction(
        key: 'continue_storyboard',
        title: '继续分镜',
        detail: '6 个分镜待确认',
        targetStep: 'storyboard',
        ctaLabel: '打开分镜步',
        launchIntent: const ProjectHomeLaunchIntent(targetStep: 'storyboard'),
      ),
      secondaryActions: const <ProjectHomeAction>[
        ProjectHomeAction(
          key: 'open_tasks',
          title: '查看任务',
          detail: '1 个运行中任务',
          targetStep: 'tasks',
          ctaLabel: '任务中心',
          launchIntent: ProjectHomeLaunchIntent(action: 'open_tasks'),
        ),
      ],
      metrics: const <ProjectHomeMetric>[
        ProjectHomeMetric(
          key: 'content',
          label: '内容',
          value: '小说 1 / 剧本 2',
          detail: '演示数据 · 可浏览完整六步流程',
        ),
        ProjectHomeMetric(
          key: 'storyboard',
          label: '分镜',
          value: '4 / 6',
          detail: '2 待生成',
          launchIntent: ProjectHomeLaunchIntent(targetStep: 'storyboard'),
        ),
      ],
      starterTemplates: const <ProjectHomeStarterTemplate>[],
    ),
  );
}

ProjectAssetsOverview buildDemoStudioAssetsOverview() {
  return const ProjectAssetsOverview(
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
      headline: '角色库已可用，还差 1 个锚点',
      subheadline: '补齐主角锚点后可进入分镜批量出图',
      primaryAction: AssetsOverviewHubAction(
        key: 'anchor_characters',
        title: '补齐角色锚点',
        detail: '林夏 仍缺少资产锚点',
        targetStep: 'assets',
        ctaLabel: '打开资产步',
      ),
      metrics: <AssetsOverviewHubMetric>[
        AssetsOverviewHubMetric(
          key: 'roles',
          label: '角色资产',
          value: '3',
          detail: '1 个待锚点',
        ),
      ],
      characterSummaries: <AssetsOverviewCharacterSummary>[
        AssetsOverviewCharacterSummary(
          characterId: 'char-lead',
          name: '林夏',
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
          name: '林夏 · 定妆',
          candidateStatus: 'linked',
          linkedScriptNumericIds: <int>[3],
          linkedCharacterNames: <String>['林夏'],
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
        'script_name': '第 1 集 · 初遇',
        'shots': <Map<String, dynamic>>[
          _demoAssemblyShotJson(
            storyboardId: 'sb-demo-101',
            storyboardNumericId: 101,
            sbIndex: 1,
            ready: true,
          ),
          _demoAssemblyShotJson(
            storyboardId: 'sb-demo-102',
            storyboardNumericId: 102,
            sbIndex: 2,
            ready: false,
          ),
          _demoAssemblyShotJson(
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
    'subtitle_text': ready ? '演示字幕 $sbIndex' : null,
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
          'text': '雨夜街头，女主撑伞回头',
        },
      ],
    },
    'scripts': <Map<String, dynamic>>[
      <String, dynamic>{
        'scriptNumericId': 3,
        'scriptName': '第 1 集 · 初遇',
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
  return ProjectDetail(
    project: ProjectRow(
      id: demoStudioProjectUuid,
      numericId: 7,
      name: '春季短剧 · 演示',
      artStylePack: 'art_skills/2D_chinese_guofeng',
      storyStylePack: 'story_skills/Family_warmth',
      artStyle: '水墨古风',
      projectAccessMode: 'inherited',
      projectAccessRole: 'owner',
    ),
    scripts: const <ScriptBrief>[
      ScriptBrief(numericId: 3, name: '第 1 集 · 初遇', extractState: 1),
      ScriptBrief(numericId: 4, name: '第 2 集 · 误会', extractState: 0),
    ],
  );
}

ListAssetsResponse buildDemoProjectAssetsList() {
  return const ListAssetsResponse(
    total: 3,
    items: <AssetRow>[
      AssetRow(
        id: 'asset-lead',
        numericId: 71,
        name: '林夏 · 定妆',
        assetType: 'role',
        description: '主角定妆照',
        candidateStatus: 'linked',
      ),
      AssetRow(
        id: 'asset-scene-1',
        numericId: 72,
        name: '雨夜街道',
        assetType: 'scene',
        description: '外景参考',
        candidateStatus: 'linked',
      ),
      AssetRow(
        id: 'asset-pending',
        numericId: 73,
        name: '咖啡馆内景',
        assetType: 'scene',
        description: '待确认候选',
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
        name: '水墨古风',
        description: l10n.projectEditorStylePackTagArt,
        tag: l10n.projectEditorStylePackTagArt,
      ),
    ],
    storyPacks: <StylePackOption>[
      StylePackOption(
        path: 'story_skills/Family_warmth',
        name: '家庭温情',
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
  return StudioReadinessSnapshot(
    completedSteps: 5,
    runningJobCount: 0,
    failedJobCount: 0,
    home: buildDemoStudioProjectHome(),
    assetsOverview: buildDemoStudioAssetsOverview(),
    readiness: buildDemoStudioShortVideoReadiness(),
    production: buildDemoStudioProductionOverview(),
  );
}

Future<ProjectStudioScriptStepDebugContent> buildDemoScriptStepContent(
  String accessToken,
  String projectUuid,
) async {
  return ProjectStudioScriptStepDebugContent(
    novels: ListNovelsResponse(
      total: 1,
      items: <NovelRow>[
        NovelRow(
          id: 'novel-demo-1',
          numericId: 501,
          chapterIndex: 1,
          chapter: '第一章 · 重逢',
          chapterData: '演示章节：男女主在雨夜重逢，埋下后续误会伏笔。',
          eventState: 0,
          intakeSource: 'paste',
          intakeStatus: 'ready',
        ),
      ],
    ),
    scripts: const <ScriptBrief>[
      ScriptBrief(
        numericId: 3,
        name: '第 1 集 · 初遇',
        extractState: 1,
      ),
      ScriptBrief(
        numericId: 4,
        name: '第 2 集 · 误会',
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

List<PublishDraftRow> buildDemoPublishDrafts() {
  return <PublishDraftRow>[
    PublishDraftRow(
      id: 'draft-demo-1',
      projectId: demoStudioProjectUuid,
      title: '第 1 集 · 竖屏成片',
      description: '演示发布草稿：待排期上传抖音。',
      tags: <String>['短剧', '都市'],
      draftStatus: 'ready',
      scriptId: '3',
      scheduledAt: '2026-05-20T10:00:00Z',
    ),
    PublishDraftRow(
      id: 'draft-demo-2',
      projectId: demoStudioProjectUuid,
      title: '第 2 集 · 竖屏成片',
      description: '演示发布草稿：可打开筛选与批量排期面板。',
      tags: <String>['短剧'],
      draftStatus: 'draft',
      scriptId: '4',
    ),
  ];
}

List<ScriptWorkbenchDetailRow> buildDemoStoryboardScripts() {
  return const <ScriptWorkbenchDetailRow>[
    ScriptWorkbenchDetailRow(
      numericId: 3,
      name: '第 1 集 · 初遇',
      relatedAssets: <ScriptRelatedAssetBrief>[],
    ),
    ScriptWorkbenchDetailRow(
      numericId: 4,
      name: '第 2 集 · 误会',
      relatedAssets: <ScriptRelatedAssetBrief>[],
    ),
  ];
}

List<ProductionStoryboardItemV1> buildDemoStoryboardShots() {
  return const <ProductionStoryboardItemV1>[
    ProductionStoryboardItemV1(
      id: 101,
      scriptId: 3,
      prompt: '雨夜街头，女主撑伞回头，霓虹映在脸上',
      state: 'ready',
      sbIndex: 1,
    ),
    ProductionStoryboardItemV1(
      id: 102,
      scriptId: 3,
      prompt: '男主近景，欲言又止，背景虚化',
      state: 'draft',
      sbIndex: 2,
    ),
    ProductionStoryboardItemV1(
      id: 103,
      scriptId: 3,
      prompt: '双人同框，误会即将解开',
      state: 'draft',
      sbIndex: 3,
    ),
  ];
}
