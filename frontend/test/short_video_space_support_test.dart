import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/short_video_space/support.dart';
import 'package:openflow_app/short_video_space/view.dart';

void main() {
  final zh = AppLocalizationsZh();
  test('short video project scope keeps uuid and workspace context', () {
    final scope = ShortVideoProjectScope.fromProject(
      const ProjectRow(
        id: '550e8400-e29b-41d4-a716-446655440000',
        workspaceId: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        numericId: 7,
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
    );

    expect(scope.projectNumericId, 7);
    expect(scope.projectUuid, '550e8400-e29b-41d4-a716-446655440000');
    expect(scope.workspaceId, 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee');
  });

  test('short video selection resolver prefers current selected project id', () {
    const projects = <ProjectRow>[
      ProjectRow(
        id: 'project-uuid-7',
        numericId: 7,
        name: 'First',
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
      ProjectRow(
        id: 'project-uuid-9',
        numericId: 9,
        name: 'Second',
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
    ];

    expect(
      resolveShortVideoSelectedProjectId(
        projects,
        currentProjectId: 'project-uuid-7',
        preferredProjectUuid: 'project-uuid-9',
      ),
      'project-uuid-7',
    );
  });

  test('short video selection resolver falls back to scoped uuid on reload', () {
    const projects = <ProjectRow>[
      ProjectRow(
        id: 'project-uuid-7',
        numericId: 7,
        name: 'First',
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
      ProjectRow(
        id: 'project-uuid-9',
        numericId: 9,
        name: 'Second',
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
    ];

    expect(
      resolveShortVideoSelectedProjectId(
        projects,
        currentProjectId: null,
        preferredProjectUuid: ' project-uuid-9 ',
      ),
      'project-uuid-9',
    );
  });

  test('short video selection resolver can prioritize updated scoped uuid', () {
    const projects = <ProjectRow>[
      ProjectRow(
        id: 'project-uuid-7',
        numericId: 7,
        name: 'First',
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
      ProjectRow(
        id: 'project-uuid-9',
        numericId: 9,
        name: 'Second',
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
    ];

    expect(
      resolveShortVideoSelectedProjectId(
        projects,
        currentProjectId: 'project-uuid-7',
        preferredProjectUuid: 'project-uuid-9',
        preferScopedProjectUuid: true,
      ),
      'project-uuid-9',
    );
  });

  test('live-action readiness highlights scene clip and manual gaps', () {
    final items = buildShortVideoReadinessItems(
      isAnimated: false,
      project: const ProjectRow(
        id: 'project-1',
        numericId: 7,
        mode: 'live_action.short_drama',
        artStylePack: 'art_skills/modern_cn',
        createTimeMs: 1,
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
      stats: const ProjectStats(
        scriptCount: 1,
        storyboardCount: 0,
        roleCount: 2,
        novelCount: 0,
        videoCount: 0,
      ),
      sceneAssetCount: 0,
      clipAssetCount: 0,
    );

    expect(items, hasLength(6));
    expect(items.where((item) => item.ready).map((item) => item.label), [
      '剧本基础',
      '角色设定',
      '视觉手册',
    ]);
    expect(items.where((item) => !item.ready).map((item) => item.label), [
      '场景参考',
      '镜头素材',
      '表演 / 口播手册',
    ]);
  });

  test('live-action next step prefers scene references before clip refs', () {
    final plan = buildShortVideoNextStepPlan(
      isAnimated: false,
      project: const ProjectRow(
        id: 'project-1',
        numericId: 7,
        mode: 'live_action.short_drama',
        artStylePack: 'art_skills/modern_cn',
        directorManual: 'spoken-showcase',
        createTimeMs: 1,
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
      stats: const ProjectStats(
        scriptCount: 1,
        storyboardCount: 1,
        roleCount: 1,
        novelCount: 0,
        videoCount: 0,
      ),
      recentProjectTasks: const TaskCenterGetTaskApiResult(
        data: <JobRow>[],
        total: 0,
      ),
      qualityScopeInsight: null,
      sceneAssetCount: 0,
      clipAssetCount: 3,
    );

    expect(plan.title, '先补真人场景参考');
    expect(plan.buttonLabel, '打开项目区补准备项');
    expect(plan.target, ShortVideoNextStepTarget.projects);
  });

  test('failed tasks override creative prep routing', () {
    final plan = buildShortVideoNextStepPlan(
      isAnimated: true,
      project: const ProjectRow(
        id: 'project-1',
        numericId: 9,
        mode: 'animated.short_drama',
        artStyle: '国风二次元',
        directorManual: 'heroic',
        createTimeMs: 1,
        projectAccessMode: 'inherited',
        projectAccessRole: 'member',
      ),
      stats: const ProjectStats(
        scriptCount: 2,
        storyboardCount: 3,
        roleCount: 2,
        novelCount: 0,
        videoCount: 0,
      ),
      recentProjectTasks: const TaskCenterGetTaskApiResult(
        data: <JobRow>[
          JobRow(
            numericTaskId: 1,
            id: 'job-1',
            ownerUserId: 'user-1',
            kind: 'video.generate',
            status: 'failed',
            payload: <String, dynamic>{},
            createdAt: '2026-05-05T00:00:00Z',
            updatedAt: '2026-05-05T00:00:00Z',
          ),
        ],
        total: 1,
      ),
      qualityScopeInsight: null,
      sceneAssetCount: 4,
      clipAssetCount: 0,
    );

    expect(plan.title, '先处理失败任务');
    expect(plan.target, ShortVideoNextStepTarget.tasks);
  });

  test('mode and ratio labels stay human readable', () {
    expect(shortVideoModeLabel(ShortVideoMode.animated), '动漫短剧');
    expect(shortVideoModeLabel(ShortVideoMode.liveAction), '真人短剧');
    expect(shortVideoVideoRatioLabel('16:9'), '横屏 16:9');
    expect(shortVideoVideoRatioLabel('9:16'), '竖屏 9:16');
  });

  test('blocking reason labels map API codes to Chinese', () {
    expect(labelShortVideoBlockingReason('missing_reference_visual'), '参考图');
    expect(
      labelShortVideoBlockingReason('missing_live_action_reference_shot'),
      '真人参考镜头',
    );
    expect(labelShortVideoBlockingReason('unknown_code'), 'unknown_code');
  });

  test('export check issue codes map to Chinese labels', () {
    expect(shortVideoExportIssueLabel(zh, 'candidate_pending'), '候选待确认');
    expect(shortVideoExportIssueLabel(zh, 'missing_selected_media'), '未选成片媒体');
    expect(shortVideoExportIssueLabel(zh, 'subtitle_empty'), '字幕为空');
    expect(shortVideoExportIssueLabel(zh, 'duration_not_set'), '时长未设定');
    expect(shortVideoExportIssueLabel(zh, 'voiceover_not_ready'), '配音未就绪');
    expect(
      shortVideoExportIssueLabel(zh, 'unknown_export_code'),
      'unknown_export_code',
    );
  });

  test('candidate card summarizes counts from assets-overview payload', () {
    final overview = ProjectAssetsOverview.fromJson({
      'schema_version': 1,
      'total_count': 5,
      'candidate_counts': {'pending': 1, 'linked': 1, 'ignored': 1, 'unset': 2},
      'by_asset_type': <dynamic>[],
    });
    final ui = buildShortVideoCandidateCardUi(
      l10n: zh,
      projectSelected: true,
      loadingProjectOverview: false,
      assetsOverview: overview,
    );
    expect(ui.pending, 1);
    expect(ui.linked, 1);
    expect(ui.ignored, 1);
    expect(ui.unset, 2);
    expect(ui.headline, isNotEmpty);
  });

  test('assets overview panel lists type rows with merged script ids', () {
    final overview = ProjectAssetsOverview.fromJson({
      'schema_version': 1,
      'total_count': 2,
      'candidate_counts': {'pending': 0, 'linked': 0, 'ignored': 0, 'unset': 2},
      'by_asset_type': [
        {
          'asset_type': 'role',
          'items': [
            {
              'asset_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
              'numeric_id': 1,
              'name': 'A',
              'asset_type': 'role',
              'candidate_status': null,
              'linked_script_numeric_ids': [3, 1],
            },
            {
              'asset_id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
              'numeric_id': 2,
              'name': 'B',
              'asset_type': 'role',
              'candidate_status': null,
              'linked_script_numeric_ids': [2],
            },
          ],
        },
      ],
    });
    final ui = buildShortVideoAssetsOverviewPanelUi(
      projectSelected: true,
      loadingProjectOverview: false,
      overview: overview,
    );
    expect(ui.typeLines, hasLength(1));
    expect(ui.typeLines.single, contains('角色'));
    expect(ui.typeLines.single, contains('剧本 #1·#2·#3'));
  });

  test('shot readiness UI summarizes rollup and blocked shots', () {
    final readiness = ProjectShortVideoReadiness.fromJson(
      jsonDecode('''
{
  "schema_version": 1,
  "rollup": {
    "total_storyboards": 2,
    "ready_count": 1,
    "blocked_count": 1,
    "by_reason": [
      { "reason": "missing_reference_visual", "storyboard_count": 1 }
    ]
  },
  "storyboards": [
    {
      "storyboard_id": "550e8400-e29b-41d4-a716-446655440000",
      "storyboard_numeric_id": 10,
      "script_numeric_id": 3,
      "sb_index": 1,
      "has_basic_slot": true,
      "has_prompt_context": true,
      "has_reference_visual": false,
      "has_live_action_reference_shots": false,
      "has_live_action_performance_notes": false,
      "candidate_cleared": true,
      "no_blocking_job": true,
      "ready_for_generation": false,
      "blocking_reasons": ["missing_reference_visual"]
    },
    {
      "storyboard_id": "650e8400-e29b-41d4-a716-446655440001",
      "storyboard_numeric_id": 11,
      "script_numeric_id": 3,
      "sb_index": 2,
      "has_basic_slot": true,
      "has_prompt_context": true,
      "has_reference_visual": true,
      "has_live_action_reference_shots": true,
      "has_live_action_performance_notes": true,
      "candidate_cleared": true,
      "no_blocking_job": true,
      "ready_for_generation": true,
      "blocking_reasons": []
    }
  ]
}
''')
          as Map<String, dynamic>,
    );
    final ui = buildShotReadinessUi(
      loadingProjectOverview: false,
      readiness: readiness,
      readinessUnavailable: false,
    );
    expect(ui.headline, contains('就绪 1/2'));
    expect(ui.reasonLines.single, contains('参考图'));
    expect(ui.shotDetailLines, isNotEmpty);
    expect(
      formatStoryboardShortVideoReadinessSummary(readiness.storyboards.first),
      contains('参考图'),
    );
  });

  test('candidate compare panel prefers blocked live-action shots first', () {
    final readiness = ProjectShortVideoReadiness.fromJson({
      'schema_version': 1,
      'rollup': {
        'total_storyboards': 2,
        'ready_count': 1,
        'blocked_count': 1,
        'by_reason': [
          {
            'reason': 'missing_live_action_reference_shot',
            'storyboard_count': 1,
          },
        ],
      },
      'storyboards': [
        {
          'storyboard_id': '550e8400-e29b-41d4-a716-446655440000',
          'storyboard_numeric_id': 10,
          'script_numeric_id': 3,
          'sb_index': 1,
          'has_basic_slot': true,
          'has_prompt_context': true,
          'has_reference_visual': true,
          'has_live_action_reference_shots': false,
          'has_live_action_performance_notes': true,
          'candidate_cleared': true,
          'no_blocking_job': true,
          'ready_for_generation': false,
          'blocking_reasons': ['missing_live_action_reference_shot'],
        },
        {
          'storyboard_id': '650e8400-e29b-41d4-a716-446655440001',
          'storyboard_numeric_id': 11,
          'script_numeric_id': 3,
          'sb_index': 2,
          'has_basic_slot': true,
          'has_prompt_context': true,
          'has_reference_visual': true,
          'has_live_action_reference_shots': true,
          'has_live_action_performance_notes': true,
          'candidate_cleared': true,
          'no_blocking_job': true,
          'ready_for_generation': true,
          'blocking_reasons': <String>[],
        },
      ],
    });
    final panel = buildShortVideoCandidateComparePanelUi(
      projectSelected: true,
      loadingProjectOverview: false,
      storyboardRows: const [
        ProductionStoryboardItemV1(
          id: 11,
          scriptId: 3,
          mediaSlots: StoryboardMediaSlotsSummaryV1(
            schemaVersion: 1,
            referenceOrPreviewFrameUrl: 'https://example.com/11.png',
            currentVideoUrl: 'https://example.com/11.mp4',
            candidateVideoSourcesHint: 'hint',
          ),
        ),
        ProductionStoryboardItemV1(
          id: 10,
          scriptId: 3,
          mediaSlots: StoryboardMediaSlotsSummaryV1(
            schemaVersion: 1,
            referenceOrPreviewFrameUrl: 'https://example.com/10.png',
            currentVideoUrl: 'https://example.com/10.mp4',
            candidateVideoSourcesHint: 'hint',
          ),
          liveActionReferenceShotUrls: ['https://example.com/ref-10.jpg'],
        ),
      ],
      readiness: readiness,
      reviews: const [
        QualityReview(
          id: 'r1',
          createdAt: '2026-05-05T00:00:00Z',
          updatedAt: '2026-05-05T00:00:00Z',
          userId: 'u1',
          projectId: 7,
          targetType: 'storyboard',
          targetId: '10',
          source: 'manual',
          passed: false,
          isBadCase: true,
        ),
      ],
      isLiveAction: true,
      onSetCurrent: null,
      onOpenProductionWorkspace: null,
    );
    expect(panel.items, hasLength(2));
    expect(panel.items.first.storyboardNumericId, 10);
    expect(panel.items.first.readinessLine, contains('真人参考镜头'));
    expect(panel.items.first.qualityLine, contains('坏例 1 条'));
  });
}
