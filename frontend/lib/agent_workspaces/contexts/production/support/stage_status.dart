part of '../support.dart';

/// Typed refresh intent for [ProductionWorkspaceStage] when
/// [ProductionWorkspaceStageStatus.suggestRefresh] is active — avoids branching
/// on user-visible detail strings.
enum ProductionWorkspaceRefreshHint {
  none,
  rereadAffectedAssets,
  refreshAssetsSnapshot,
  rereadPartialStoryboardTable,
  refreshStoryboardTableSnapshot,
  rereadMissingFrameState,
  refreshStoryboardSnapshot,
}

/// Machine-readable production stage status; chip text uses
/// [ProductionWorkspaceStageStatusL10n.localizedLabel].
enum ProductionWorkspaceStageStatus {
  supervisionNeedsRework,
  supervisionPendingRevision,
  supervisionCanAdvance,
  supervisionApproved,
  pendingGenerate,
  pendingRefineScriptPlan,
  pendingReview,
  suggestRefresh,
  pendingRead,
  pendingAssetPlan,
  needsAssetImages,
  assetsReady,
  assetsScopedFromRefs,
  waitingScriptPlanDepth,
  assetsNarrowedFromScriptPlan,
  waitingScriptPlan,
  storyboardTableSampled,
  storyboardTableExpandRead,
  backfillScriptPlanFromTable,
  needsStoryboardFrames,
  storyboardFramesPending,
  storyboardPendingVerify,
  storyboardComplete,
  waitingStoryboardTable,
  waitingStoryboardTableCoverage;

  bool get isResolvedForPrimaryBlocker => switch (this) {
    ProductionWorkspaceStageStatus.assetsReady ||
    ProductionWorkspaceStageStatus.storyboardComplete ||
    ProductionWorkspaceStageStatus.storyboardTableSampled => true,
    _ => false,
  };

  static ProductionWorkspaceStageStatus fromSupervisionReview(
    ProductionSupervisionReview review,
  ) {
    if (review.severeCount > 0 || review.grade == 'D') {
      return ProductionWorkspaceStageStatus.supervisionNeedsRework;
    }
    if (review.grade == 'C') {
      return ProductionWorkspaceStageStatus.supervisionPendingRevision;
    }
    if (review.grade == 'B') {
      return ProductionWorkspaceStageStatus.supervisionCanAdvance;
    }
    return ProductionWorkspaceStageStatus.supervisionApproved;
  }
}
