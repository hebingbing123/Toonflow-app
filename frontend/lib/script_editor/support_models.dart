part of 'support.dart';

class ScriptWorkbenchDiagnosis {
  const ScriptWorkbenchDiagnosis({
    required this.summary,
    required this.detail,
    required this.recommendedAction,
  });

  final String summary;
  final String detail;
  final ScriptWorkbenchRecommendedAction recommendedAction;
}

enum ScriptWorkbenchRecommendedAction {
  syncWorkbench,
  pollExtractState,
  startExtractAssets,
  openEditImageWorkbench,
  exportScriptZip,
}

class ScriptBatchWorkbenchDiagnosis {
  const ScriptBatchWorkbenchDiagnosis({
    required this.summary,
    required this.detail,
    required this.recommendedAction,
  });

  final String summary;
  final String detail;
  final ScriptBatchWorkbenchRecommendedAction recommendedAction;
}

enum ScriptBatchWorkbenchRecommendedAction {
  syncContext,
  pollSelected,
  startExtractSelected,
  exportSelectedZip,
}
