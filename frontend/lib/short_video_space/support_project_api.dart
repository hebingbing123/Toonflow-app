import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'support_models.dart';
import 'view.dart';

bool shortVideoHasVisualStyleSignal(ProjectRow? project) {
  if (project == null) {
    return false;
  }
  return (project.artStyle ?? '').trim().isNotEmpty ||
      (project.artStylePack ?? '').trim().isNotEmpty;
}

bool shortVideoHasDirectionSignal(ProjectRow? project) {
  if (project == null) {
    return false;
  }
  return (project.directorManual ?? '').trim().isNotEmpty ||
      (project.storyStylePack ?? '').trim().isNotEmpty;
}

String? shortVideoVisualStyleLabel(ProjectRow? project, AppLocalizations l10n) {
  if (project == null) {
    return null;
  }
  final pack = (project.artStylePack ?? '').trim();
  if (pack.isNotEmpty) {
    return l10n.shortVideoProjectVisualStylePack(pack);
  }
  final style = (project.artStyle ?? '').trim();
  if (style.isNotEmpty) {
    return l10n.shortVideoProjectVisualArtStyle(style);
  }
  return null;
}

String? shortVideoDirectionLabel(ProjectRow? project, AppLocalizations l10n) {
  if (project == null) {
    return null;
  }
  final pack = (project.storyStylePack ?? '').trim();
  if (pack.isNotEmpty) {
    return l10n.shortVideoProjectDirectionStoryPack(pack);
  }
  final manual = (project.directorManual ?? '').trim();
  if (manual.isNotEmpty) {
    return l10n.shortVideoProjectDirectionManual(manual);
  }
  return null;
}

String shortVideoModeLabelL10n(AppLocalizations l10n, ShortVideoMode mode) {
  return mode == ShortVideoMode.animated
      ? l10n.shortVideoSpaceModeTitleAnimated
      : l10n.shortVideoSpaceModeTitleLive;
}

String shortVideoVideoRatioLabelL10n(AppLocalizations l10n, String ratio) {
  switch (ratio) {
    case '16:9':
      return l10n.shortVideoSpaceAspectRatioLandscape169;
    case '1:1':
      return l10n.shortVideoSpaceAspectRatioSquare11;
    default:
      return l10n.shortVideoSpaceAspectRatioPortrait916;
  }
}

String shortVideoProjectReadinessSummary(
  ProjectStats? stats,
  AppLocalizations l10n,
) {
  if (stats == null) {
    return l10n.shortVideoProjectReadinessAwaitingStats;
  }
  if (stats.scriptCount <= 0) {
    return l10n.shortVideoProjectReadinessNoScript;
  }
  if (stats.storyboardCount <= 0) {
    return l10n.shortVideoProjectReadinessNoStoryboard;
  }
  if (stats.roleCount <= 0) {
    return l10n.shortVideoProjectReadinessNoRoles;
  }
  return l10n.shortVideoProjectReadinessProductionReady;
}

String shortVideoSpaceOverviewSummary({
  required AppLocalizations l10n,
  required bool loadingProjectOverview,
  required ProjectRow? project,
  required ProjectStats? projectStats,
  required TaskCenterGetTaskApiResult? recentProjectTasks,
  required QualityScopeInsightRow? qualityScopeInsight,
}) {
  if (loadingProjectOverview) {
    return l10n.shortVideoSpaceOverviewAggregating;
  }
  if (project == null) {
    return l10n.shortVideoSpaceOverviewSelectProjectFirst;
  }
  final taskCount = recentProjectTasks?.total ?? 0;
  final runningCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'running',
  );
  final failedCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'failed',
  );
  if (projectStats == null) {
    return l10n.shortVideoSpaceOverviewProjectSelectedNoStats;
  }
  if (failedCount > 0) {
    return l10n.shortVideoSpaceOverviewRecentFailedTasks(failedCount);
  }
  if (runningCount > 0) {
    return l10n.shortVideoSpaceOverviewRunningTasks(runningCount);
  }
  if ((qualityScopeInsight?.badCaseCount ?? 0) > 0) {
    return l10n.shortVideoSpaceOverviewBadCaseRecords(
      qualityScopeInsight!.badCaseCount,
    );
  }
  if (taskCount <= 0) {
    return shortVideoProjectReadinessSummary(projectStats, l10n);
  }
  return l10n.shortVideoSpaceOverviewRecentTaskRecords(taskCount);
}

int shortVideoCountTasksByStatus(
  TaskCenterGetTaskApiResult? tasks,
  String status,
) {
  final rows = tasks?.data ?? const <JobRow>[];
  return rows.where((row) => row.status == status).length;
}

ShortVideoNextStepPlan buildShortVideoNextStepPlan({
  required AppLocalizations l10n,
  required bool isAnimated,
  required ProjectRow? project,
  required ProjectStats? stats,
  required TaskCenterGetTaskApiResult? recentProjectTasks,
  required QualityScopeInsightRow? qualityScopeInsight,
  required int sceneAssetCount,
  required int clipAssetCount,
}) {
  final failedCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'failed',
  );
  if (project == null) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepPickProjectTitle,
      detail: l10n.shortVideoNextStepPickProjectDetail,
      buttonLabel: l10n.shortVideoNextStepCtaGoProjectsFirst,
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (failedCount > 0) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepFailedTasksTitle,
      detail: l10n.shortVideoNextStepFailedTasksDetail,
      buttonLabel: l10n.shortVideoNextStepCtaOpenTasks,
      target: ShortVideoNextStepTarget.tasks,
    );
  }
  if ((qualityScopeInsight?.badCaseCount ?? 0) > 0) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepQualityTitle,
      detail: isAnimated
          ? l10n.shortVideoNextStepQualityDetailAnimated
          : l10n.shortVideoNextStepQualityDetailLive,
      buttonLabel: l10n.shortVideoNextStepCtaOpenQuality,
      target: ShortVideoNextStepTarget.quality,
    );
  }
  if (isAnimated && !shortVideoHasVisualStyleSignal(project)) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepAnimVisualStyleTitle,
      detail: l10n.shortVideoNextStepAnimVisualStyleDetail,
      buttonLabel: l10n.shortVideoNextStepCtaOpenProjectsPrep,
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && sceneAssetCount <= 0) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepLiveSceneRefsTitle,
      detail: l10n.shortVideoNextStepLiveSceneRefsDetail,
      buttonLabel: l10n.shortVideoNextStepCtaOpenProjectsPrep,
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && clipAssetCount <= 0) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepLiveClipRefsTitle,
      detail: l10n.shortVideoNextStepLiveClipRefsDetail,
      buttonLabel: l10n.shortVideoNextStepCtaOpenProjectsPrep,
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && !shortVideoHasDirectionSignal(project)) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepLivePerformManualTitle,
      detail: l10n.shortVideoNextStepLivePerformManualDetail,
      buttonLabel: l10n.shortVideoNextStepCtaOpenProjectsPrep,
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (stats == null || stats.scriptCount <= 0) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepFirstScriptTitle,
      detail: isAnimated
          ? l10n.shortVideoNextStepFirstScriptDetailAnimated
          : l10n.shortVideoNextStepFirstScriptDetailLive,
      buttonLabel: l10n.shortVideoNextStepCtaOpenScriptWorkspace,
      target: ShortVideoNextStepTarget.scriptWorkspace,
    );
  }
  if (stats.storyboardCount <= 0) {
    return ShortVideoNextStepPlan(
      title: l10n.shortVideoNextStepStoryboardTitle,
      detail: l10n.shortVideoNextStepStoryboardDetail,
      buttonLabel: l10n.shortVideoNextStepCtaOpenScriptWorkspace,
      target: ShortVideoNextStepTarget.scriptWorkspace,
    );
  }
  if (stats.roleCount <= 0) {
    return ShortVideoNextStepPlan(
      title: isAnimated
          ? l10n.shortVideoNextStepRolesAnimTitle
          : l10n.shortVideoNextStepRolesLiveTitle,
      detail: isAnimated
          ? l10n.shortVideoNextStepRolesAnimDetail
          : l10n.shortVideoNextStepRolesLiveDetail,
      buttonLabel: l10n.shortVideoNextStepCtaOpenProductionWorkspace,
      target: ShortVideoNextStepTarget.productionWorkspace,
    );
  }
  return ShortVideoNextStepPlan(
    title: l10n.shortVideoNextStepProductionReadyTitle,
    detail: isAnimated
        ? l10n.shortVideoNextStepProductionReadyDetailAnimated
        : l10n.shortVideoNextStepProductionReadyDetailLive,
    buttonLabel: l10n.shortVideoNextStepCtaOpenProductionWorkspace,
    target: ShortVideoNextStepTarget.productionWorkspace,
  );
}
