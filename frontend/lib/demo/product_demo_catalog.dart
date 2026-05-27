import '../account/controller.dart';
import '../api_keys/controller.dart';
import '../content_compliance/controller.dart';
import '../jobs/controller.dart';
import '../notifications/controller.dart';
import '../platform/studio_load_state.dart';
import '../project_studio/project_studio_scope.dart';
import '../projects/controller.dart';
import '../quality_reviews/controller.dart';
import '../rust_api.dart';
import '../task_center/controller.dart';
import 'agent_workspace_demo_data.dart';
import 'benchmark_demo_data.dart';
import 'compliance_demo_data.dart';
import 'help_hub_demo_data.dart';
import 'platform_config_demo_data.dart';
import 'platform_status_demo_data.dart';
import 'product_demo_mode.dart';
import '../debug/project_studio_script_debug_preview.dart';
import 'short_video_demo_data.dart';
import 'studio_demo_data.dart';

const demoProjectUuid = demoStudioProjectUuid;

final _demoNotificationCreatedAt1 = DateTime.utc(2026, 5, 10);
final _demoNotificationChangedAt2 = DateTime.utc(2026, 5, 11, 8);
final _demoNotificationReadAt2 = DateTime.utc(2026, 5, 11, 9);
final _demoWorkspaceCreatedAt = DateTime.utc(2026, 4, 1);
final _demoQualityStageReviewDate = DateTime.utc(2026, 5, 10);

/// Full in-memory product shell dataset for demo mode and widget tests.
class ProductDemoCatalog {
  const ProductDemoCatalog({
    this.productScopedProjectNumericId,
    this.projects,
    this.artStyles,
    this.projectsSummaryLine,
    this.artStylesLine,
    this.taskProjects,
    this.taskApiJobs,
    this.taskCategoriesLine,
    this.taskApiSummaryLine,
    this.jobs,
    this.qualityReviews,
    this.qualityStatsLine,
    this.qualityStagePassRateLine,
    this.qualityReviewByIdLine,
    this.notificationItems,
    this.notificationUnreadCount = 0,
    this.complianceQueue,
    this.studioSnapshotLoader,
    this.scriptStepContentLoader,
    this.helpHubWebhooks,
    this.helpHubLatestCreatedWebhook,
    this.helpHubBillingEventsPage,
    this.helpHubWebhookDeliveries,
    this.helpHubWebhookLastTestResults,
    this.sessionMe,
    this.platformConfig,
    this.apiKeyItems,
    this.apiKeyAuditItems,
    this.workspaceListItems,
    this.publishDrafts,
    this.platformStatusSnapshot,
    this.storyboardDebugScripts,
    this.storyboardDebugShots,
    this.agentWorkspaceSnapshot,
    this.benchmarkSnapshot,
    this.shortVideoOverviewSnapshot,
    this.platformConfigResponse,
  });

  final int? productScopedProjectNumericId;
  final List<ProjectRow>? projects;
  final List<ArtStyleRow>? artStyles;
  final String? projectsSummaryLine;
  final String? artStylesLine;
  final List<TaskCenterProjectItem>? taskProjects;
  final List<JobRow>? taskApiJobs;
  final String? taskCategoriesLine;
  final String? taskApiSummaryLine;
  final List<JobRow>? jobs;
  final List<QualityReview>? qualityReviews;
  final String? qualityStatsLine;
  final String? qualityStagePassRateLine;
  final String? qualityReviewByIdLine;
  final List<NotificationRecordV1>? notificationItems;
  final int notificationUnreadCount;
  final ContentComplianceQueueResponseV1? complianceQueue;
  final ProjectStudioReadinessLoader? studioSnapshotLoader;
  final ProjectStudioScriptStepContentLoader? scriptStepContentLoader;
  final OutboundWebhookListResponseV1? helpHubWebhooks;
  final OutboundWebhookCreatedResponseV1? helpHubLatestCreatedWebhook;
  final BillingWebhookEventsResponseV1? helpHubBillingEventsPage;
  final Map<String, OutboundWebhookDeliveryListResponseV1>? helpHubWebhookDeliveries;
  final Map<String, OutboundWebhookTestResponseV1>? helpHubWebhookLastTestResults;
  final MeResponse? sessionMe;
  final PlatformConfigToggleSetV1? platformConfig;
  final List<ApiKeyRecordV1>? apiKeyItems;
  final List<ApiKeyAuditRecordV1>? apiKeyAuditItems;
  final List<WorkspaceListItem>? workspaceListItems;
  final List<PublishDraftRow>? publishDrafts;
  final PlatformStatusDemoSnapshot? platformStatusSnapshot;
  final List<ScriptWorkbenchDetailRow>? storyboardDebugScripts;
  final List<ProductionStoryboardItemV1>? storyboardDebugShots;
  final AgentWorkspaceDemoSnapshot? agentWorkspaceSnapshot;
  final BenchmarkDemoSnapshot? benchmarkSnapshot;
  final ShortVideoDemoSnapshot? shortVideoOverviewSnapshot;
  final PlatformConfigResponseV1? platformConfigResponse;

  static ProductDemoCatalog buildDefault() {
    return ProductDemoCatalog(
      productScopedProjectNumericId: 7,
      projects: const <ProjectRow>[
        ProjectRow(
          id: demoProjectUuid,
          numericId: 7,
          name: '春季短剧 · 演示',
          createTimeMs: 1,
          projectAccessMode: 'inherited',
          projectAccessRole: 'owner',
          artStylePack: 'art_skills/2D_chinese_guofeng',
          storyStylePack: 'story_skills/Family_warmth',
          artStyle: '水墨古风',
        ),
        ProjectRow(
          id: '00000000-0000-0000-0000-000000000008',
          numericId: 8,
          name: '都市情感 · 第二季',
          createTimeMs: 2,
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
      ],
      artStyles: const <ArtStyleRow>[
        ArtStyleRow(
          id: 'style-ink',
          numericId: 11,
          name: '水墨古风',
          label: 'ink',
          prompt: 'soft ink wash, muted palette',
          fileUrl: '/api/v1/art-styles/numeric/11/cover',
        ),
      ],
      projectsSummaryLine: 'projects=2',
      artStylesLine: 'total=1',
      taskProjects: const <TaskCenterProjectItem>[
        TaskCenterProjectItem(
          numericId: 7,
          name: '春季短剧 · 演示',
          projectUuid: demoProjectUuid,
        ),
      ],
      taskCategoriesLine: '分类 2 个 · asset.generate.image, script.export.zip',
      taskApiSummaryLine: 'page=1 limit=10 · total=3 · page_rows=3',
      taskApiJobs: const <JobRow>[
        JobRow(
          numericTaskId: 101,
          id: 'job-101',
          ownerUserId: 'demo-user',
          kind: 'asset.generate.image',
          status: 'queued',
          payload: <String, dynamic>{'project_numeric_id': 7},
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:01:00Z',
        ),
        JobRow(
          numericTaskId: 102,
          id: 'job-102',
          ownerUserId: 'demo-user',
          kind: 'script.export.zip',
          status: 'running',
          payload: <String, dynamic>{'project_numeric_id': 7},
          createdAt: '2026-04-10T00:02:00Z',
          updatedAt: '2026-04-10T00:03:00Z',
        ),
        JobRow(
          numericTaskId: 103,
          id: 'job-103',
          ownerUserId: 'demo-user',
          kind: 'render.completed',
          status: 'failed',
          payload: <String, dynamic>{'project_numeric_id': 7},
          errorMessage: 'provider timeout',
          createdAt: '2026-04-10T00:04:00Z',
          updatedAt: '2026-04-10T00:05:00Z',
        ),
      ],
      jobs: const <JobRow>[
        JobRow(
          numericTaskId: 201,
          id: 'job-201',
          ownerUserId: 'demo-user',
          kind: 'flutter.probe',
          status: 'queued',
          payload: <String, dynamic>{'workspace_id': 'workspace-demo'},
          createdAt: '2026-05-12T00:00:00Z',
          updatedAt: '2026-05-12T00:01:00Z',
        ),
        JobRow(
          numericTaskId: 202,
          id: 'job-202',
          ownerUserId: 'demo-user-2',
          kind: 'render.completed',
          status: 'failed',
          payload: <String, dynamic>{'project_numeric_id': 7},
          createdAt: '2026-05-12T00:02:00Z',
          updatedAt: '2026-05-12T00:03:00Z',
        ),
      ],
      qualityReviews: const <QualityReview>[
        QualityReview(
          id: 'review-1',
          createdAt: '2026-04-14T08:00:00Z',
          updatedAt: '2026-04-14T08:00:00Z',
          userId: 'demo-user',
          targetType: 'output',
          source: 'manual',
          overallScore: 82,
          passed: true,
          isBadCase: false,
          suggestedAction: 'patch_storyboard_items',
        ),
        QualityReview(
          id: 'review-2',
          createdAt: '2026-04-15T09:00:00Z',
          updatedAt: '2026-04-15T09:00:00Z',
          userId: 'demo-user',
          targetType: 'storyboard',
          source: 'auto',
          overallScore: 61,
          passed: false,
          isBadCase: true,
          suggestedAction: 'review_storyboard_prompt',
        ),
      ],
      qualityStatsLine: 'output: total=2, pass=50%',
      qualityStagePassRateLine: 'storyboard: 100%',
      qualityReviewByIdLine: 'review-1 · output · manual',
      notificationItems: <NotificationRecordV1>[
        NotificationRecordV1(
          id: 1,
          userId: 'demo-user',
          workspaceId: 'workspace-demo',
          projectId: demoProjectUuid,
          projectNumericId: 7,
          jobId: 'job-101',
          notificationType: 'export.ready',
          title: '导出已完成',
          message: '项目「春季短剧 · 演示」导出包已就绪，可在任务中心下载。',
          linkPath: '/?pane=tasks',
          payload: <String, dynamic>{'project_numeric_id': 7},
          filePath: null,
          changedAt: null,
          readAt: null,
          createdAt: _demoNotificationCreatedAt1,
          updatedAt: _demoNotificationCreatedAt1,
        ),
        NotificationRecordV1(
          id: 2,
          userId: 'demo-user',
          workspaceId: 'workspace-demo',
          projectId: demoProjectUuid,
          projectNumericId: 7,
          jobId: 'job-103',
          notificationType: 'job.failed',
          title: '渲染任务失败',
          message: 'render.completed 超时，请在工作台重试。',
          linkPath: '/?pane=tasks',
          payload: <String, dynamic>{'project_numeric_id': 7},
          filePath: null,
          changedAt: _demoNotificationChangedAt2,
          readAt: _demoNotificationReadAt2,
          createdAt: _demoNotificationChangedAt2,
          updatedAt: _demoNotificationReadAt2,
        ),
      ],
      notificationUnreadCount: 1,
      complianceQueue: buildDemoContentComplianceQueue(),
      studioSnapshotLoader: buildDemoStudioReadinessSnapshot,
      scriptStepContentLoader: buildDemoScriptStepContent,
      helpHubWebhooks: buildDemoHelpHubWebhookList(),
      helpHubLatestCreatedWebhook: buildDemoHelpHubLatestCreatedWebhook(),
      helpHubBillingEventsPage: buildDemoHelpHubBillingEventsPage(),
      helpHubWebhookDeliveries: buildDemoHelpHubWebhookDeliveries(),
      helpHubWebhookLastTestResults: buildDemoHelpHubWebhookLastTestResults(),
      sessionMe: MeResponse(
        sub: 'demo-user',
        email: 'creator@demo.openflow',
        planTier: 'pro',
        billingCurrency: 'CNY',
        billingProvider: 'stripe',
        subscriptionStatus: 'active',
        subscriptionCurrentPeriodEndAt: DateTime.utc(2026, 12, 31),
        dailyJobQuota: 200,
        jobsToday: 12,
        currentWorkspace: const WorkspaceSummary(
          id: 'workspace-demo',
          name: '演示工作区',
          workspaceType: 'team',
        ),
      ),
      platformConfig: PlatformConfigToggleSetV1.defaults,
      apiKeyItems: <ApiKeyRecordV1>[
        ApiKeyRecordV1(
          id: 'key-demo-1',
          publicId: 'ofk_demo_01',
          displayName: '桌面客户端 · 演示',
          scope: ApiKeyScopeV1.readWrite,
          status: ApiKeyStatusV1.active,
          keyHint: '•••• 7a2f',
          useCount: 42,
          isExpired: false,
          isUsable: true,
          createdAt: '2026-04-01T00:00:00Z',
          updatedAt: '2026-05-01T00:00:00Z',
          lastUsedAt: '2026-05-10T08:00:00Z',
          lastUsedPath: '/api/v1/projects',
          lastUsedMethod: 'GET',
        ),
      ],
      apiKeyAuditItems: const <ApiKeyAuditRecordV1>[
        ApiKeyAuditRecordV1(
          id: 'audit-demo-1',
          apiKeyId: 'key-demo-1',
          eventType: 'created',
          eventSummary: '创建 API 密钥',
          metadata: <String, dynamic>{},
          createdAt: '2026-04-01T00:00:00Z',
        ),
      ],
      workspaceListItems: <WorkspaceListItem>[
        WorkspaceListItem(
          role: 'owner',
          workspace: WorkspaceResponse(
            id: 'workspace-demo',
            ownerUserId: 'demo-user',
            name: '演示工作区',
            workspaceType: 'team',
            metadata: const <String, dynamic>{'demo': true},
            createdAt: _demoWorkspaceCreatedAt,
            updatedAt: _demoWorkspaceCreatedAt,
          ),
        ),
        WorkspaceListItem(
          role: 'member',
          workspace: WorkspaceResponse(
            id: 'workspace-archive',
            ownerUserId: 'demo-user',
            name: '归档示例',
            workspaceType: 'personal',
            metadata: const <String, dynamic>{},
            archivedAt: DateTime.utc(2026, 3, 1),
            createdAt: _demoWorkspaceCreatedAt,
            updatedAt: _demoWorkspaceCreatedAt,
          ),
        ),
      ],
      publishDrafts: buildDemoPublishDrafts(),
      platformStatusSnapshot: buildDemoPlatformStatusSnapshot(),
      storyboardDebugScripts: buildDemoStoryboardScripts(),
      storyboardDebugShots: buildDemoStoryboardShots(),
      agentWorkspaceSnapshot: buildDemoAgentWorkspaceSnapshot(),
      benchmarkSnapshot: buildDemoBenchmarkSnapshot(),
      shortVideoOverviewSnapshot: buildDemoShortVideoOverviewSnapshot(),
      platformConfigResponse: buildDemoPlatformConfigResponse(),
    );
  }

  void applyTo({
    required ProjectsController projectsController,
    required TaskCenterController taskCenterController,
    required JobsController jobsController,
    required QualityReviewsController qualityReviewsController,
    required NotificationsController notificationsController,
    required ContentComplianceController contentComplianceController,
    ApiKeysController? apiKeysController,
    AccountController? accountController,
  }) {
    final skipLiveApi = ProductDemoMode.instance.isActive;
    if (skipLiveApi) {
      projectsController.skipDemoApi = true;
      taskCenterController.skipDemoApi = true;
      jobsController.skipDemoApi = true;
      qualityReviewsController.skipDemoApi = true;
    }

    if (projects != null) {
      projectsController.projects = projects;
      projectsController.loadingProjects = false;
      projectsController.skipDemoMutations = ProductDemoMode.instance.isActive;
      if (projectsSummaryLine != null) {
        projectsController.projectsSummaryLine = projectsSummaryLine;
      }
    }
    if (artStyles != null) {
      projectsController.artStyles = artStyles;
      projectsController.loadingArtStyles = false;
      if (artStylesLine != null) {
        projectsController.artStylesLine = artStylesLine;
      }
    }

    if (taskApiJobs != null) {
      taskCenterController.taskApiJobs = taskApiJobs;
      taskCenterController.taskApiLoadState = StudioLoadState.success;
      taskCenterController.loadingTaskApi = false;
    }
    if (taskProjects != null) {
      taskCenterController.taskProjects = taskProjects;
      taskCenterController.loadingTaskProjects = false;
    }
    if (taskCategoriesLine != null) {
      taskCenterController.taskCategoriesLine = taskCategoriesLine;
      taskCenterController.loadingTaskCategories = false;
    }
    if (taskApiSummaryLine != null) {
      taskCenterController.taskApiSummaryLine = taskApiSummaryLine;
    }

    if (jobs != null) {
      jobsController.jobs = jobs;
      jobsController.jobsLoadState = StudioLoadState.success;
      jobsController.loadingJobs = false;
      jobsController.jobKindsLine = 'flutter.probe, render.completed';
      jobsController.jobKindSummaryLine =
          'flutter.probe(1), render.completed(1)';
      jobsController.jobStatusSummaryLine = 'queued(1), failed(1)';
    }

    if (qualityReviews != null) {
      qualityReviewsController.qualityReviews = qualityReviews;
      qualityReviewsController.qualityReviewsLoadState = StudioLoadState.success;
      qualityReviewsController.loadingQualityReviews = false;
      qualityReviewsController.loadingQualityDashboard = false;
      qualityReviewsController.qualityDashboardLoadState = StudioLoadState.success;
      if (skipLiveApi) {
        qualityReviewsController.qualityStatsRows = const <QualityDashboardTargetStat>[
          QualityDashboardTargetStat(
            scope: 'project',
            targetType: 'storyboard',
            totalReviews: 12,
            passRatePercent: 83.3,
            avgOverallScore: 78.5,
          ),
          QualityDashboardTargetStat(
            scope: 'project',
            targetType: 'output',
            totalReviews: 8,
            passRatePercent: 75.0,
            avgOverallScore: 72.0,
          ),
        ];
        qualityReviewsController.qualityStagePassRateRows =
            <QualityDashboardStagePassRateItem>[
          QualityDashboardStagePassRateItem(
            scope: 'project',
            targetType: 'storyboard',
            reviewDate: _demoQualityStageReviewDate,
            totalReviews: 6,
            passRatePercent: 100,
          ),
        ];
      }
    }
    if (qualityStatsLine != null) {
      qualityReviewsController.qualityStatsLine = qualityStatsLine;
    }
    if (qualityStagePassRateLine != null) {
      qualityReviewsController.qualityStagePassRateLine = qualityStagePassRateLine;
    }
    if (qualityReviewByIdLine != null) {
      qualityReviewsController.qualityReviewByIdLine = qualityReviewByIdLine;
    }

    if (notificationItems != null) {
      notificationsController.applyDebugPreview(
        items: notificationItems!,
        unreadCount: notificationUnreadCount,
      );
    }

    if (complianceQueue != null) {
      contentComplianceController.queueEnabledOverride = true;
      contentComplianceController.skipAutoLoadQueueOnMount = true;
      contentComplianceController.queue = complianceQueue;
    }

    apiKeysController?.applyDemoPreview(
      items: apiKeyItems ?? const <ApiKeyRecordV1>[],
      auditItems: apiKeyAuditItems ?? const <ApiKeyAuditRecordV1>[],
      activeCount: apiKeyItems?.where((k) => k.status == ApiKeyStatusV1.active).length ?? 0,
      revokedCount: apiKeyItems?.where((k) => k.status == ApiKeyStatusV1.revoked).length ?? 0,
    );

    accountController?.applyDemoPreview(
      activeCount: apiKeyItems?.length ?? 1,
    );
  }
}
