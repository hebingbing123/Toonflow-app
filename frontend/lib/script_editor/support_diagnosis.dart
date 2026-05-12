part of 'support.dart';

ScriptWorkbenchDiagnosis diagnoseScriptWorkbench(
  AppLocalizations l10n, {
  ScriptWorkbenchDetailRow? scriptContext,
  ScriptExtractStatePollRow? extractStateRow,
}) {
  if (scriptContext == null && extractStateRow == null) {
    return ScriptWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisSingleNoSnapshotSummary,
      detail: l10n.projectEditorScriptsDiagnosisSingleNoSnapshotDetail,
      recommendedAction: ScriptWorkbenchRecommendedAction.syncWorkbench,
    );
  }

  final extractState =
      extractStateRow?.extractState ?? scriptContext?.extractState;
  final trimmedError =
      (extractStateRow?.errorReason ?? scriptContext?.errorReason ?? '').trim();
  final relatedAssets =
      scriptContext?.relatedAssets ?? const <ScriptRelatedAssetBrief>[];

  if (extractState != null && extractState < 0) {
    return ScriptWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisSingleExtractFailedSummary,
      detail: trimmedError.isEmpty
          ? l10n.projectEditorScriptsDiagnosisSingleExtractFailedDetailNoReason
          : l10n.projectEditorScriptsDiagnosisSingleExtractFailedDetailWithReason(
              trimmedError,
            ),
      recommendedAction: ScriptWorkbenchRecommendedAction.startExtractAssets,
    );
  }

  if (extractState != null && extractState > 0) {
    return ScriptWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisSingleExtractRunningSummary,
      detail: l10n.projectEditorScriptsDiagnosisSingleExtractRunningDetail,
      recommendedAction: ScriptWorkbenchRecommendedAction.pollExtractState,
    );
  }

  if (relatedAssets.isEmpty) {
    return ScriptWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisSingleNoAssetsSummary,
      detail: l10n.projectEditorScriptsDiagnosisSingleNoAssetsDetail,
      recommendedAction: ScriptWorkbenchRecommendedAction.startExtractAssets,
    );
  }

  return ScriptWorkbenchDiagnosis(
    summary: l10n.projectEditorScriptsDiagnosisSingleHasAssetsSummary,
    detail: l10n.projectEditorScriptsDiagnosisSingleHasAssetsDetail(
      relatedAssets.length,
    ),
    recommendedAction: ScriptWorkbenchRecommendedAction.openEditImageWorkbench,
  );
}

ScriptBatchWorkbenchDiagnosis diagnoseScriptBatchWorkbench(
  AppLocalizations l10n, {
  required Iterable<int> selectedIds,
  required Iterable<ScriptBrief> scripts,
  required Iterable<ScriptWorkbenchDetailRow> previewRows,
}) {
  final selected = selectedIds.toList(growable: false);
  if (selected.isEmpty) {
    return ScriptBatchWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisBatchEmptySummary,
      detail: l10n.projectEditorScriptsDiagnosisBatchEmptyDetail,
      recommendedAction: ScriptBatchWorkbenchRecommendedAction.syncContext,
    );
  }

  final previewById = <int, ScriptWorkbenchDetailRow>{
    for (final row in previewRows) row.numericId: row,
  };
  final scriptById = <int, ScriptBrief>{
    for (final row in scripts) row.numericId: row,
  };

  var runningCount = 0;
  var failedCount = 0;
  var withAssetsCount = 0;
  for (final id in selected) {
    final preview = previewById[id];
    final extractState = preview?.extractState ?? scriptById[id]?.extractState;
    if (extractState != null && extractState > 0) {
      runningCount += 1;
    } else if (extractState != null && extractState < 0) {
      failedCount += 1;
    }
    if ((preview?.relatedAssets.length ?? 0) > 0) {
      withAssetsCount += 1;
    }
  }

  if (runningCount > 0) {
    return ScriptBatchWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisBatchRunningSummary(
        runningCount,
      ),
      detail: l10n.projectEditorScriptsDiagnosisBatchRunningDetail,
      recommendedAction: ScriptBatchWorkbenchRecommendedAction.pollSelected,
    );
  }

  if (failedCount > 0) {
    return ScriptBatchWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisBatchFailedSummary(failedCount),
      detail: l10n.projectEditorScriptsDiagnosisBatchFailedDetail,
      recommendedAction:
          ScriptBatchWorkbenchRecommendedAction.startExtractSelected,
    );
  }

  final previewCoverage = selected.where(previewById.containsKey).length;
  if (previewCoverage < selected.length) {
    return ScriptBatchWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisBatchMissingContextSummary(
        selected.length,
      ),
      detail: l10n.projectEditorScriptsDiagnosisBatchMissingContextDetail,
      recommendedAction: ScriptBatchWorkbenchRecommendedAction.syncContext,
    );
  }

  if (withAssetsCount == selected.length && selected.isNotEmpty) {
    return ScriptBatchWorkbenchDiagnosis(
      summary: l10n.projectEditorScriptsDiagnosisBatchAllAssetsSummary(
        selected.length,
      ),
      detail: l10n.projectEditorScriptsDiagnosisBatchAllAssetsDetail,
      recommendedAction:
          ScriptBatchWorkbenchRecommendedAction.exportSelectedZip,
    );
  }

  return ScriptBatchWorkbenchDiagnosis(
    summary: l10n.projectEditorScriptsDiagnosisBatchPendingExtractSummary(
      selected.length,
    ),
    detail: l10n.projectEditorScriptsDiagnosisBatchPendingExtractDetail,
    recommendedAction:
        ScriptBatchWorkbenchRecommendedAction.startExtractSelected,
  );
}
