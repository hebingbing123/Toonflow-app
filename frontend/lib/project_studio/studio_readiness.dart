import '../rust_api.dart';

/// Maps project APIs to six-step SOP completion (0–6).
class StudioReadinessSnapshot {
  const StudioReadinessSnapshot({
    required this.completedSteps,
    this.readiness,
    this.production,
    this.home,
    this.assetsOverview,
    this.runningJobCount = 0,
    this.failedJobCount = 0,
  });

  final int completedSteps;
  final ProjectShortVideoReadiness? readiness;
  final ProjectProductionOverview? production;
  final ProjectHome? home;
  final ProjectAssetsOverview? assetsOverview;

  /// Active generation jobs for this project (`queued` + `running`).
  final int runningJobCount;
  final int failedJobCount;
}

int computeStudioCompletedSteps({
  ProjectShortVideoReadiness? readiness,
  ProjectProductionOverview? production,
}) {
  var steps = 1;

  final totalSb =
      production?.totalStoryboardCount ??
      readiness?.rollup.totalStoryboards ??
      0;
  final readySb =
      readiness?.rollup.readyCount ?? production?.readyStoryboardCount ?? 0;

  if (totalSb > 0) {
    steps = steps < 4 ? 4 : steps;
  }
  if (totalSb > 0 && readySb > 0) {
    steps = steps < 5 ? 5 : steps;
  }
  if (totalSb > 0 && readySb >= totalSb) {
    steps = 6;
  } else if (totalSb > 0 && readySb / totalSb >= 0.6) {
    steps = steps < 5 ? 5 : steps;
  }

  return steps.clamp(0, 6);
}
