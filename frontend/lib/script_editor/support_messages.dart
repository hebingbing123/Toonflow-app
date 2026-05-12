part of 'support.dart';

String scriptWorkbenchRecommendedActionLabel(
  AppLocalizations l10n,
  ScriptWorkbenchRecommendedAction action,
) {
  switch (action) {
    case ScriptWorkbenchRecommendedAction.syncWorkbench:
      return l10n.projectEditorScriptsSingleWorkbenchRecommendSyncWorkbench;
    case ScriptWorkbenchRecommendedAction.pollExtractState:
      return l10n.projectEditorScriptsSingleWorkbenchRecommendPollExtractState;
    case ScriptWorkbenchRecommendedAction.startExtractAssets:
      return l10n.projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets;
    case ScriptWorkbenchRecommendedAction.openEditImageWorkbench:
      return l10n
          .projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench;
    case ScriptWorkbenchRecommendedAction.exportScriptZip:
      return l10n.projectEditorScriptsSingleWorkbenchRecommendExportScriptZip;
  }
}

String scriptBatchWorkbenchRecommendedActionLabel(
  AppLocalizations l10n,
  ScriptBatchWorkbenchRecommendedAction action,
) {
  switch (action) {
    case ScriptBatchWorkbenchRecommendedAction.syncContext:
      return l10n.projectEditorScriptsWorkbenchRecommendSyncContext;
    case ScriptBatchWorkbenchRecommendedAction.pollSelected:
      return l10n.projectEditorScriptsWorkbenchRecommendPollSelected;
    case ScriptBatchWorkbenchRecommendedAction.startExtractSelected:
      return l10n.projectEditorScriptsWorkbenchRecommendExtractSelected;
    case ScriptBatchWorkbenchRecommendedAction.exportSelectedZip:
      return l10n.projectEditorScriptsWorkbenchRecommendExportSelected;
  }
}

String buildScriptWorkbenchFollowUp(
  AppLocalizations l10n, {
  required String actionSummary,
  required ScriptWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = scriptWorkbenchRecommendedActionLabel(
    l10n,
    diagnosis.recommendedAction,
  );
  return l10n.projectEditorScriptsWorkbenchBatchFollowUpLine(
    actionSummary,
    nextAction,
    diagnosis.detail,
  );
}

String buildScriptBatchWorkbenchFollowUp(
  AppLocalizations l10n, {
  required String actionSummary,
  required ScriptBatchWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = scriptBatchWorkbenchRecommendedActionLabel(
    l10n,
    diagnosis.recommendedAction,
  );
  return l10n.projectEditorScriptsWorkbenchBatchFollowUpLine(
    actionSummary,
    nextAction,
    diagnosis.detail,
  );
}

ScriptWorkbenchDetailRow? findScriptContextByNumericId(
  Iterable<ScriptWorkbenchDetailRow> rows,
  int numericId,
) {
  for (final row in rows) {
    if (row.numericId == numericId) {
      return row;
    }
  }
  return null;
}

ScriptExtractStatePollRow? findScriptExtractStateByNumericId(
  Iterable<ScriptExtractStatePollRow> rows,
  int numericId,
) {
  for (final row in rows) {
    if (row.numericId == numericId) {
      return row;
    }
  }
  return null;
}

String describeScriptExtractState(
  AppLocalizations l10n, {
  int? extractState,
  String? errorReason,
}) {
  if (extractState == null) {
    return l10n.projectEditorScriptsExtractStateEmpty;
  }
  final trimmedError = (errorReason ?? '').trim();
  final suffix = trimmedError.isEmpty ? '' : ' · $trimmedError';
  return l10n.projectEditorScriptsExtractStateLine(extractState, suffix);
}
