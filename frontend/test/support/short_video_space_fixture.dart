import 'package:flutter/material.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/short_video_space/desktop_capability.dart';
import 'package:openflow_app/short_video_space/support.dart';
import 'package:openflow_app/short_video_space/view.dart';

/// Minimal [ShortVideoSpaceView] for widget/golden tests (no project selected).
Widget buildShortVideoOverviewFixture(
  AppLocalizations l10n, {
  ShortVideoLatestExportUi latestExportUi = const ShortVideoLatestExportUi(),
  VoidCallback? onRetryLatestExportTask,
  VoidCallback? onOpenProductionForAssemblyExport,
  VoidCallback? onOpenExportHistory,
}) {
  const projectSelected = false;
  final readinessItems = buildShortVideoReadinessItems(
    l10n,
    isAnimated: true,
    project: null,
    stats: null,
    sceneAssetCount: 0,
    clipAssetCount: 0,
  );
  final nextStep = buildShortVideoNextStepPlan(
    l10n: l10n,
    isAnimated: true,
    project: null,
    stats: null,
    recentProjectTasks: null,
    qualityScopeInsight: null,
    sceneAssetCount: 0,
    clipAssetCount: 0,
  );
  final stageCards = <ShortVideoStageCardData>[
    ShortVideoStageCardData(
      title: l10n.shortVideoStageCard1Title,
      status: l10n.shortVideoStageCard1Status,
      detail: l10n.shortVideoStageCard1DetailAnimated,
    ),
    ShortVideoStageCardData(
      title: l10n.shortVideoStageCard2Title,
      status: l10n.shortVideoStageCard2Status,
      detail: l10n.shortVideoStageCard2DetailAnimated,
    ),
  ];

  return ShortVideoSpaceView(
    desktopCapabilityPanel: const ShortVideoDesktopCapabilityPanel(
      runtimeDescriptor: DesktopRuntimeDescriptor(
        kind: DesktopRuntimeKind.webBrowser,
        headline: 'Browser workspace',
        detail: 'Use the desktop app for local editing and final assembly.',
        supportsDesktopBridge: false,
        showDownloadCallToAction: false,
      ),
    ),
    mode: ShortVideoMode.animated,
    modeTitle: l10n.shortVideoSpaceModeTitleAnimated,
    modeSummary: l10n.shortVideoSpaceModeSummaryAnimated,
    modeAdvice: l10n.shortVideoSpaceModeAdviceAnimated,
    onModeChanged: (_) {},
    loadingProjects: false,
    projectOptions: const <ShortVideoProjectOption>[],
    selectedProjectId: null,
    onProjectChanged: (_) {},
    onRefreshProjects: () {},
    videoRatio: '9:16',
    onVideoRatioChanged: (_) {},
    targetMarket: 'domestic',
    onTargetMarketChanged: (_) {},
    targetPlatforms: const <String>[],
    onPublishPlatformTapped: (_) {},
    durationStrategy: 'auto',
    onDurationStrategyChanged: (_) {},
    voiceProfile: '',
    onVoiceProfileChanged: (_) {},
    subtitleStyle: '',
    onSubtitleStyleChanged: (_) {},
    bgmStrategy: '',
    onBgmStrategyChanged: (_) {},
    creatingProject: false,
    onCreateProject: () {},
    savingProjectConfig: false,
    onSaveProjectConfig: () {},
    onOpenProjects: () {},
    projectConfigLine: null,
    operationFeedbackIsSuccess: null,
    loadingProjectOverview: false,
    projectReadinessSummary: shortVideoProjectReadinessSummary(null, l10n),
    visualLabel: null,
    directionLabel: null,
    projectMetrics: const <ShortVideoMetricData>[],
    spaceOverviewSummary: shortVideoSpaceOverviewSummary(
      l10n: l10n,
      loadingProjectOverview: false,
      project: null,
      projectStats: null,
      recentProjectTasks: null,
      qualityScopeInsight: null,
    ),
    overviewMetrics: const <ShortVideoMetricData>[],
    qualitySummaryLine: shortVideoQualitySummaryLine(
      l10n,
      isAnimated: true,
      insight: null,
    ),
    badCaseMetrics: const <ShortVideoMetricData>[],
    recentTaskLines: const <String>[],
    assetsOverviewPanelUi: buildShortVideoAssetsOverviewPanelUi(
      l10n: l10n,
      projectSelected: projectSelected,
      loadingProjectOverview: false,
      overview: null,
    ),
    assemblyPanelUi: buildShortVideoAssemblyPanelUi(
      l10n: l10n,
      projectSelected: projectSelected,
      loadingProjectOverview: false,
      assembly: null,
    ),
    assemblyInputPanelUi: buildAssemblyInputPanelUi(
      l10n: l10n,
      projectSelected: projectSelected,
      loadingProjectOverview: false,
      assembly: null,
      exportCheck: null,
    ),
    exportCheckPanelUi: buildShortVideoExportCheckPanelUi(
      l10n: l10n,
      projectSelected: projectSelected,
      loadingProjectOverview: false,
      exportCheck: null,
    ),
    latestExportUi: latestExportUi,
    onOpenExportHistory: onOpenExportHistory,
    onRetryLatestExportTask: onRetryLatestExportTask,
    onOpenProductionForAssemblyExport: onOpenProductionForAssemblyExport,
    localAssemblyBlockedHint:
        'Use the desktop app for local editing and final assembly.',
    publishPanelUi: buildShortVideoPublishPanelUi(
      l10n: l10n,
      projectSelected: projectSelected,
      loadingProjectOverview: false,
      publishUnavailable: true,
      exportCheck: null,
      matrix: null,
      drafts: const <PublishDraftRow>[],
      prepare: null,
      jobs: const <PublishJobRow>[],
      performanceAlerts: const <PublishPerformanceAlertRow>[],
      audits: const <PublishAttemptAuditRow>[],
      selectedPublishDraftId: null,
      publishBusy: false,
    ),
    onOpenDesktopDownloads: () {},
    candidateCardUi: buildShortVideoCandidateCardUi(
      l10n: l10n,
      projectSelected: projectSelected,
      loadingProjectOverview: false,
      assetsOverview: null,
    ),
    candidateComparePanelUi: buildShortVideoCandidateComparePanelUi(
      l10n: l10n,
      projectSelected: projectSelected,
      loadingProjectOverview: false,
      storyboardRows: const <ProductionStoryboardItemV1>[],
      readiness: null,
      reviews: const <QualityReview>[],
      isLiveAction: false,
      onSetCurrent: null,
      onOpenProductionWorkspace: null,
    ),
    readinessIntro: l10n.shortVideoReadinessIntroAnimated,
    readinessCountLabel:
        '${readinessItems.where((i) => i.ready).length}/${readinessItems.length}',
    readinessGapSummary: shortVideoReadinessGapSummary(
      l10n,
      isAnimated: true,
      readinessItems: readinessItems,
    ),
    readinessItems: readinessItems,
    shotReadinessUi: ShotReadinessUi(
      headline: l10n.shortVideoShotReadinessSelectProjectHint,
    ),
    nextStepTitle: nextStep.title,
    nextStepDetail: nextStep.detail,
    onNextStep: () {},
    nextStepButtonLabel: nextStep.buttonLabel,
    stageCards: stageCards,
    migrationSummary: l10n.shortVideoMigrationSummaryAnimated,
    onOpenScriptWorkspace: () {},
    onOpenProductionWorkspace: () {},
    onOpenTasks: () {},
    onOpenQuality: () {},
  );
}
