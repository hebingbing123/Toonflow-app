import '../rust_api.dart';
import 'studio_demo_data.dart';

/// Preloaded short-video space state for demo mode (project overview slice).
class ShortVideoDemoSnapshot {
  const ShortVideoDemoSnapshot({
    this.projectStats,
    this.productionOverview,
    this.assetsOverview,
    this.shotReadiness,
    this.shotReadinessUnavailable = false,
    this.publishDrafts = const <PublishDraftRow>[],
    this.candidateCompareRows = const <ProductionStoryboardItemV1>[],
    this.candidateCompareReviews = const <QualityReview>[],
    this.scopedRunningJobCount = 0,
    this.projectConfigLine,
    this.assembly,
    this.exportCheck,
    this.timeline,
    this.recentProjectTasks,
  });

  final ProjectStats? projectStats;
  final ProjectProductionOverview? productionOverview;
  final ProjectAssetsOverview? assetsOverview;
  final ProjectShortVideoReadiness? shotReadiness;
  final bool shotReadinessUnavailable;
  final List<PublishDraftRow> publishDrafts;
  final List<ProductionStoryboardItemV1> candidateCompareRows;
  final List<QualityReview> candidateCompareReviews;
  final int scopedRunningJobCount;
  final String? projectConfigLine;
  final ProjectShortVideoAssembly? assembly;
  final ProjectShortVideoExportCheck? exportCheck;
  final ProjectShortVideoTimelineV1? timeline;
  final TaskCenterGetTaskApiResult? recentProjectTasks;
}

ShortVideoDemoSnapshot buildDemoShortVideoOverviewSnapshot() {
  final l10n = rustApiLookupL10nFromPlatform();
  return ShortVideoDemoSnapshot(
    projectStats: const ProjectStats(
      scriptCount: 2,
      storyboardCount: 6,
      roleCount: 3,
      novelCount: 1,
      videoCount: 0,
    ),
    productionOverview: buildDemoStudioProductionOverview(),
    assetsOverview: buildDemoStudioAssetsOverview(l10n),
    shotReadiness: buildDemoStudioShortVideoReadiness(),
    publishDrafts: buildDemoPublishDrafts(l10n),
    candidateCompareRows: buildDemoStoryboardShots(),
    candidateCompareReviews: const <QualityReview>[
      QualityReview(
        id: 'review-sv-1',
        createdAt: '2026-04-14T08:00:00Z',
        updatedAt: '2026-04-14T08:00:00Z',
        userId: 'demo-user',
        targetType: 'storyboard',
        source: 'auto',
        overallScore: 78,
        passed: true,
        isBadCase: false,
      ),
    ],
    scopedRunningJobCount: 1,
    projectConfigLine: l10n.demoShortVideoProjectConfigLine,
    assembly: buildDemoStudioShortVideoAssembly(),
    exportCheck: buildDemoStudioShortVideoExportCheck(),
    timeline: buildDemoStudioShortVideoTimeline(),
    recentProjectTasks: buildDemoRecentProjectTasks(),
  );
}
