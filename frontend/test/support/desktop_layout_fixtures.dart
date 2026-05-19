import 'package:flutter/material.dart';
import 'package:openflow_app/account/controller.dart';
import 'package:openflow_app/api_keys/controller.dart';
import 'package:openflow_app/auth/controller.dart';
import 'package:openflow_app/jobs/controller.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/platform/studio_load_state.dart';
import 'package:openflow_app/projects/controller.dart';
import 'package:openflow_app/quality_reviews/controller.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/task_center/section.dart';

export 'content_compliance_fixtures.dart';

/// Shared controllers for desktop layout widget goldens (mirrors integration gallery).
AuthController buildDesktopGalleryAuthController() {
  return AuthController(
    onErrorChanged: (_) {},
    onSignedOut: () async {},
    l10nProvider: () => null,
  );
}

ProjectsController buildDesktopGalleryProjectsController() {
  final controller = ProjectsController(
    accessTokenProvider: () => 'token',
    onErrorChanged: (_) {},
    l10nProvider: () => null,
  );
  controller.projects = const <ProjectRow>[
    ProjectRow(
      id: 'project-1',
      numericId: 11,
      name: '项目一',
      createTimeMs: 1,
      projectAccessMode: 'inherited',
      projectAccessRole: 'member',
    ),
  ];
  controller.artStyles = const <ArtStyleRow>[
    ArtStyleRow(
      id: 'style-1',
      numericId: 11,
      name: '水墨古风',
      label: 'ink',
      prompt: 'soft ink wash',
      fileUrl: '/api/v1/art-styles/numeric/11/cover',
    ),
  ];
  controller.projectsSummaryLine = 'projects=1';
  controller.artStylesLine = 'total=1';
  return controller;
}

QualityReviewsController buildDesktopGalleryQualityController() {
  final controller = QualityReviewsController(
    accessTokenProvider: () => 'token',
    onErrorChanged: (_) {},
  );
  controller.qualityReviews = const <QualityReview>[
    QualityReview(
      id: 'r1',
      createdAt: '2026-04-10T00:00:00Z',
      updatedAt: '2026-04-10T00:00:00Z',
      userId: 'u1',
      targetType: 'output',
      source: 'manual',
      overallScore: 82,
      isBadCase: false,
    ),
  ];
  controller.qualityStatsLine = 'output: total=1, pass=100%';
  controller.qualityStagePassRateLine = '2026-04-10 output:100%';
  controller.qualityReviewByIdLine = 'r1 · output · manual';
  controller.loadingQualityDashboard = false;
  controller.qualityDashboardLoadState = StudioLoadState.success;
  return controller;
}

JobsController buildDesktopGalleryJobsController() {
  final controller = JobsController(
    accessTokenProvider: () => 'token',
    onErrorChanged: (_) {},
    l10nProvider: () => null,
  );
  controller.jobs = const <JobRow>[
    JobRow(
      numericTaskId: 201,
      id: 'job-201',
      ownerUserId: 'user-1',
      kind: 'flutter.probe',
      status: 'queued',
      payload: <String, dynamic>{'workspace_id': 'workspace-beta'},
      createdAt: '2026-05-12T00:00:00Z',
      updatedAt: '2026-05-12T00:01:00Z',
    ),
    JobRow(
      numericTaskId: 202,
      id: 'job-202',
      ownerUserId: 'user-2',
      kind: 'render.completed',
      status: 'failed',
      payload: <String, dynamic>{'project_numeric_id': 11},
      createdAt: '2026-05-12T00:02:00Z',
      updatedAt: '2026-05-12T00:03:00Z',
    ),
  ];
  controller.jobKindsLine = 'flutter.probe, render.completed';
  controller.jobKindSummaryLine = 'flutter.probe(1), render.completed(1)';
  controller.jobStatusSummaryLine = 'queued(1), failed(1)';
  controller.jobByIdLine = '#202 · render.completed · failed · uuid=job-202';
  controller.jobIdController.text = 'job-202';
  controller.loadingJobs = false;
  controller.jobsLoadState = StudioLoadState.success;
  return controller;
}

({AccountController account, ApiKeysController apiKeys})
buildDesktopGallerySettingsControllers() {
  final zh = AppLocalizationsZh();
  return (
    account: AccountController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => zh,
    ),
    apiKeys: ApiKeysController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => zh,
    ),
  );
}

Widget buildDesktopGalleryTaskCenter({
  required TextEditingController taskDetailController,
}) {
  return SingleChildScrollView(
    child: TaskCenterSection(
      accessToken: 'token',
      initialProjectNumericId: 9,
      initialProjectUuid: '550e8400-e29b-41d4-a716-446655440009',
      loadingTaskProjects: false,
      loadingTaskCategories: false,
      loadingTaskApi: false,
      loadingTaskDetailsByNumericId: false,
      loadingTaskDetailsUuid: false,
      taskDetailJobIdController: taskDetailController,
      taskProjects: const <TaskCenterProjectItem>[
        TaskCenterProjectItem(
          numericId: 9,
          name: '古风短剧',
          projectUuid: '550e8400-e29b-41d4-a716-446655440009',
        ),
      ],
      taskCategoriesLine: '分类 2 个 · asset.generate.image, script.export.zip',
      taskApiSummaryLine: 'page=1 limit=10 · total=1 · page_rows=1',
      taskDetailNumericIdLine:
          '#101 · asset.generate.image · queued · uuid=job-101',
      taskDetailUuidLine:
          '#101 · asset.generate.image · queued · uuid=job-101',
      taskApiJobs: const <JobRow>[
        JobRow(
          numericTaskId: 101,
          id: 'job-101',
          ownerUserId: 'user-1',
          kind: 'asset.generate.image',
          status: 'queued',
          payload: <String, dynamic>{'project_numeric_id': 9},
          createdAt: '2026-04-10T00:00:00Z',
          updatedAt: '2026-04-10T00:01:00Z',
        ),
      ],
      taskApiLoadState: StudioLoadState.success,
      onTaskDetailJobIdChanged: (_) {},
      onLoadTaskProjects: () {},
      onLoadTaskCategories: () {},
      onLoadTaskApi: () {},
      onProbeTaskDetailByNumericId: () {},
      onProbeTaskDetailUuid: () {},
      onSelectTaskJob: (_) {},
    ),
  );
}
