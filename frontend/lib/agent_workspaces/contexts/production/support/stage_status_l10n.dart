part of '../support.dart';

extension ProductionWorkspaceStageStatusL10n on ProductionWorkspaceStageStatus {
  String localizedLabel(AppLocalizations l10n) {
    return switch (this) {
      ProductionWorkspaceStageStatus.supervisionNeedsRework =>
        l10n.agentWorkspaceProductionStageStatusSupervisionNeedsRework,
      ProductionWorkspaceStageStatus.supervisionPendingRevision =>
        l10n.agentWorkspaceProductionStageStatusSupervisionPendingRevision,
      ProductionWorkspaceStageStatus.supervisionCanAdvance =>
        l10n.agentWorkspaceProductionStageStatusSupervisionCanAdvance,
      ProductionWorkspaceStageStatus.supervisionApproved =>
        l10n.agentWorkspaceProductionStageStatusSupervisionApproved,
      ProductionWorkspaceStageStatus.pendingGenerate =>
        l10n.agentWorkspaceProductionStageStatusPendingGenerate,
      ProductionWorkspaceStageStatus.pendingRefineScriptPlan =>
        l10n.agentWorkspaceProductionStageStatusPendingRefineScriptPlan,
      ProductionWorkspaceStageStatus.pendingReview =>
        l10n.agentWorkspaceProductionStageStatusPendingReview,
      ProductionWorkspaceStageStatus.suggestRefresh =>
        l10n.agentWorkspaceProductionStageStatusSuggestRefresh,
      ProductionWorkspaceStageStatus.pendingRead =>
        l10n.agentWorkspaceProductionStageStatusPendingRead,
      ProductionWorkspaceStageStatus.pendingAssetPlan =>
        l10n.agentWorkspaceProductionStageStatusPendingAssetPlan,
      ProductionWorkspaceStageStatus.needsAssetImages =>
        l10n.agentWorkspaceProductionStageStatusNeedsAssetImages,
      ProductionWorkspaceStageStatus.assetsReady =>
        l10n.agentWorkspaceProductionStageStatusAssetsReady,
      ProductionWorkspaceStageStatus.assetsScopedFromRefs =>
        l10n.agentWorkspaceProductionStageStatusAssetsScopedFromRefs,
      ProductionWorkspaceStageStatus.waitingScriptPlanDepth =>
        l10n.agentWorkspaceProductionStageStatusWaitingScriptPlanDepth,
      ProductionWorkspaceStageStatus.assetsNarrowedFromScriptPlan =>
        l10n.agentWorkspaceProductionStageStatusAssetsNarrowedFromScriptPlan,
      ProductionWorkspaceStageStatus.waitingScriptPlan =>
        l10n.agentWorkspaceProductionStageStatusWaitingScriptPlan,
      ProductionWorkspaceStageStatus.storyboardTableSampled =>
        l10n.agentWorkspaceProductionStageStatusStoryboardTableSampled,
      ProductionWorkspaceStageStatus.storyboardTableExpandRead =>
        l10n.agentWorkspaceProductionStageStatusStoryboardTableExpandRead,
      ProductionWorkspaceStageStatus.backfillScriptPlanFromTable =>
        l10n.agentWorkspaceProductionStageStatusBackfillScriptPlanFromTable,
      ProductionWorkspaceStageStatus.needsStoryboardFrames =>
        l10n.agentWorkspaceProductionStageStatusNeedsStoryboardFrames,
      ProductionWorkspaceStageStatus.storyboardFramesPending =>
        l10n.agentWorkspaceProductionStageStatusStoryboardFramesPending,
      ProductionWorkspaceStageStatus.storyboardPendingVerify =>
        l10n.agentWorkspaceProductionStageStatusStoryboardPendingVerify,
      ProductionWorkspaceStageStatus.storyboardComplete =>
        l10n.agentWorkspaceProductionStageStatusStoryboardComplete,
      ProductionWorkspaceStageStatus.waitingStoryboardTable =>
        l10n.agentWorkspaceProductionStageStatusWaitingStoryboardTable,
      ProductionWorkspaceStageStatus.waitingStoryboardTableCoverage =>
        l10n.agentWorkspaceProductionStageStatusWaitingStoryboardTableCoverage,
    };
  }
}
