import 'dart:math' as math;

import '../rust_api.dart';
import 'studio_step.dart';

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

/// Ring steps aligned with creator-journey milestones (project + nav index).
///
/// Matches the «六步工作流» sheet: on deliver, project + four prior milestones
/// are marked complete → `5/6`, not `1/6` from empty storyboard APIs alone.
int studioProgressRingStepsFromJourney(StudioStep step) {
  final nav = switch (step) {
    StudioStep.script => 1,
    StudioStep.art || StudioStep.assets => 2,
    StudioStep.storyboard || StudioStep.video => 3,
    StudioStep.deliver || StudioStep.quality => 4,
  };
  return (nav + 1).clamp(1, 6);
}

/// Combines API-derived progress with the user's current studio route.
int resolveStudioProgressRingSteps(
  int dataSteps, {
  StudioStep? currentStep,
}) {
  final data = dataSteps.clamp(0, 6);
  if (currentStep == null) {
    return data <= 0 ? 1 : data;
  }
  return math.max(data, studioProgressRingStepsFromJourney(currentStep));
}

/// Progress for projects-home cards: API rollup + last visited studio step.
int computeProjectListProgressSteps({
  ProjectShortVideoReadiness? readiness,
  ProjectProductionOverview? production,
  StudioStep? lastVisitedStep,
}) {
  return resolveStudioProgressRingSteps(
    computeStudioCompletedSteps(
      readiness: readiness,
      production: production,
    ),
    currentStep: lastVisitedStep,
  );
}
