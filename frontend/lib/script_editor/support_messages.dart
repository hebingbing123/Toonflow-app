part of 'support.dart';

String describeScriptWorkbenchRecommendedAction(
  ScriptWorkbenchRecommendedAction action,
) {
  switch (action) {
    case ScriptWorkbenchRecommendedAction.syncWorkbench:
      return '同步工作台';
    case ScriptWorkbenchRecommendedAction.pollExtractState:
      return '轮询提取状态';
    case ScriptWorkbenchRecommendedAction.startExtractAssets:
      return '提取当前剧本素材';
    case ScriptWorkbenchRecommendedAction.openEditImageWorkbench:
      return '进入编辑图片工作台';
    case ScriptWorkbenchRecommendedAction.exportScriptZip:
      return '导出当前剧本 ZIP';
  }
}

String describeScriptBatchWorkbenchRecommendedAction(
  ScriptBatchWorkbenchRecommendedAction action,
) {
  switch (action) {
    case ScriptBatchWorkbenchRecommendedAction.syncContext:
      return '读取剧本上下文';
    case ScriptBatchWorkbenchRecommendedAction.pollSelected:
      return '轮询所选状态';
    case ScriptBatchWorkbenchRecommendedAction.startExtractSelected:
      return '提取所选素材';
    case ScriptBatchWorkbenchRecommendedAction.exportSelectedZip:
      return '导出所选剧本';
  }
}

String buildScriptWorkbenchFollowUp({
  required String actionSummary,
  required ScriptWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeScriptWorkbenchRecommendedAction(
    diagnosis.recommendedAction,
  );
  return '$actionSummary 下一步建议：$nextAction。${diagnosis.detail}';
}

String buildScriptBatchWorkbenchFollowUp({
  required String actionSummary,
  required ScriptBatchWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeScriptBatchWorkbenchRecommendedAction(
    diagnosis.recommendedAction,
  );
  return '$actionSummary 下一步建议：$nextAction。${diagnosis.detail}';
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

String describeScriptExtractState({
  int? extractState,
  String? errorReason,
  String emptyLabel = '当前脚本提取状态为空：通常表示 idle 或已完成。',
}) {
  if (extractState == null) {
    return emptyLabel;
  }
  final trimmedError = (errorReason ?? '').trim();
  return '提取状态 $extractState'
      '${trimmedError.isEmpty ? '' : ' · $trimmedError'}';
}
