import 'package:openflow_app/debug/project_studio_script_debug_preview.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/rust_api.dart';

const previewStudioProjectUuid = '00000000-0000-0000-0000-000000000007';

/// Rich [ProjectHome] for studio art / cockpit widget tests.
ProjectHome buildPreviewStudioProjectHome() {
  return ProjectHome(
    project: ProjectRow(
      id: previewStudioProjectUuid,
      numericId: 7,
      name: '春季短剧 · E2E 预览',
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
      headline: '春季短剧 · E2E 预览',
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
          detail: '最近更新于预览数据',
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

/// Asset hub snapshot for assets-step chrome.
ProjectAssetsOverview buildPreviewStudioAssetsOverview() {
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
        detail: 'Lead 仍缺少资产锚点',
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

ProjectShortVideoReadiness buildPreviewStudioShortVideoReadiness() {
  return ProjectShortVideoReadiness.fromJson(<String, dynamic>{
    'rollup': <String, dynamic>{
      'totalStoryboards': 6,
      'readyCount': 4,
      'blockedCount': 1,
    },
    'items': <dynamic>[],
  });
}

ProjectProductionOverview buildPreviewStudioProductionOverview() {
  return ProjectProductionOverview.fromJson(<String, dynamic>{
    'totalStoryboardCount': 6,
    'readyStoryboardCount': 4,
    'scriptCount': 2,
  });
}

Future<StudioReadinessSnapshot> buildPreviewStudioReadinessSnapshot(
  String accessToken,
  String projectUuid,
) async {
  return StudioReadinessSnapshot(
    completedSteps: 5,
    runningJobCount: 1,
    failedJobCount: 1,
    home: buildPreviewStudioProjectHome(),
    assetsOverview: buildPreviewStudioAssetsOverview(),
    readiness: buildPreviewStudioShortVideoReadiness(),
    production: buildPreviewStudioProductionOverview(),
  );
}

Future<ProjectStudioScriptStepDebugContent> buildPreviewScriptStepContent(
  String accessToken,
  String projectUuid,
) async {
  return ProjectStudioScriptStepDebugContent(
    novels: ListNovelsResponse(
      total: 1,
      items: <NovelRow>[
        NovelRow(
          id: 'novel-preview-1',
          numericId: 501,
          chapterIndex: 1,
          chapter: '第一章 · 重逢',
          chapterData: '预览章节正文，用于 widget 测试。',
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
