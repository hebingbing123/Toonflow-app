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

/// Machine-readable production stage status; UI copy must come from l10n
/// (commit 2). [legacyChineseLabel] preserves prior Chinese chip strings until then.
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

  /// Until ARB wiring (commit 2), preserves prior Chinese chip / blocker strings.
  String get legacyChineseLabel => switch (this) {
    ProductionWorkspaceStageStatus.supervisionNeedsRework => '需返工',
    ProductionWorkspaceStageStatus.supervisionPendingRevision => '待修订',
    ProductionWorkspaceStageStatus.supervisionCanAdvance => '可推进',
    ProductionWorkspaceStageStatus.supervisionApproved => '已通过',
    ProductionWorkspaceStageStatus.pendingGenerate => '待生成',
    ProductionWorkspaceStageStatus.pendingRefineScriptPlan => '待完善',
    ProductionWorkspaceStageStatus.pendingReview => '待审核',
    ProductionWorkspaceStageStatus.suggestRefresh => '建议刷新',
    ProductionWorkspaceStageStatus.pendingRead => '待读取',
    ProductionWorkspaceStageStatus.pendingAssetPlan => '待规划',
    ProductionWorkspaceStageStatus.needsAssetImages => '需补图',
    ProductionWorkspaceStageStatus.assetsReady => '已齐备',
    ProductionWorkspaceStageStatus.assetsScopedFromRefs => '已定位',
    ProductionWorkspaceStageStatus.waitingScriptPlanDepth => '等待导演计划完善',
    ProductionWorkspaceStageStatus.assetsNarrowedFromScriptPlan => '已收紧',
    ProductionWorkspaceStageStatus.waitingScriptPlan => '等待导演计划',
    ProductionWorkspaceStageStatus.storyboardTableSampled => '已抽样',
    ProductionWorkspaceStageStatus.storyboardTableExpandRead => '待扩读',
    ProductionWorkspaceStageStatus.backfillScriptPlanFromTable => '回补导演计划',
    ProductionWorkspaceStageStatus.needsStoryboardFrames => '需补帧',
    ProductionWorkspaceStageStatus.storyboardFramesPending => '待补帧',
    ProductionWorkspaceStageStatus.storyboardPendingVerify => '待核对',
    ProductionWorkspaceStageStatus.storyboardComplete => '已完成',
    ProductionWorkspaceStageStatus.waitingStoryboardTable => '等待分镜表',
    ProductionWorkspaceStageStatus.waitingStoryboardTableCoverage => '等待分镜表完善',
  };

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
