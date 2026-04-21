part of 'support.dart';

ScriptWorkbenchDiagnosis diagnoseScriptWorkbench({
  ScriptWorkbenchDetailRow? scriptContext,
  ScriptExtractStatePollRow? extractStateRow,
}) {
  if (scriptContext == null && extractStateRow == null) {
    return const ScriptWorkbenchDiagnosis(
      summary: '还没有当前剧本的工作台快照。',
      detail: '先同步工作台，读取 get-script-api 上下文和最近一次提取状态。',
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
      summary: '素材提取最近一次执行失败。',
      detail: trimmedError.isEmpty
          ? '建议修正输入后重新发起当前剧本素材抽取。'
          : '失败原因：$trimmedError，建议修正后重新发起当前剧本素材抽取。',
      recommendedAction: ScriptWorkbenchRecommendedAction.startExtractAssets,
    );
  }

  if (extractState != null && extractState > 0) {
    return ScriptWorkbenchDiagnosis(
      summary: '素材提取正在进行中。',
      detail: '建议先轮询提取状态，确认任务是否完成，再决定是否进入图片编辑流程。',
      recommendedAction: ScriptWorkbenchRecommendedAction.pollExtractState,
    );
  }

  if (relatedAssets.isEmpty) {
    return const ScriptWorkbenchDiagnosis(
      summary: '当前剧本还没有关联素材。',
      detail: '可以直接发起素材抽取，把脚本上下文转成后续图片与分镜流程可用的资产。',
      recommendedAction: ScriptWorkbenchRecommendedAction.startExtractAssets,
    );
  }

  return ScriptWorkbenchDiagnosis(
    summary: '当前剧本已有关联素材。',
    detail: '已同步 ${relatedAssets.length} 条关联素材，可继续进入编辑图片工作台，或先导出 ZIP 做本地审阅。',
    recommendedAction: ScriptWorkbenchRecommendedAction.openEditImageWorkbench,
  );
}

ScriptBatchWorkbenchDiagnosis diagnoseScriptBatchWorkbench({
  required Iterable<int> selectedIds,
  required Iterable<ScriptBrief> scripts,
  required Iterable<ScriptWorkbenchDetailRow> previewRows,
}) {
  final selected = selectedIds.toList(growable: false);
  if (selected.isEmpty) {
    return const ScriptBatchWorkbenchDiagnosis(
      summary: '还没有选择要处理的剧本。',
      detail: '先读取剧本上下文或填写目标剧本 id，再执行批量导出、轮询或素材抽取。',
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
      summary: '所选剧本里有 $runningCount 条仍在提取中。',
      detail: '建议先轮询所选状态，确认批量任务是否完成，再决定是否重试抽取。',
      recommendedAction: ScriptBatchWorkbenchRecommendedAction.pollSelected,
    );
  }

  if (failedCount > 0) {
    return ScriptBatchWorkbenchDiagnosis(
      summary: '所选剧本里有 $failedCount 条最近提取失败。',
      detail: '建议重新发起所选剧本素材抽取，优先收敛失败项。',
      recommendedAction:
          ScriptBatchWorkbenchRecommendedAction.startExtractSelected,
    );
  }

  final previewCoverage = selected.where(previewById.containsKey).length;
  if (previewCoverage < selected.length) {
    return ScriptBatchWorkbenchDiagnosis(
      summary: '所选 ${selected.length} 条剧本还缺少上下文快照。',
      detail: '建议先读取剧本上下文，确认哪些剧本已有素材，再决定导出 ZIP 还是补做素材抽取。',
      recommendedAction: ScriptBatchWorkbenchRecommendedAction.syncContext,
    );
  }

  if (withAssetsCount == selected.length && selected.isNotEmpty) {
    return ScriptBatchWorkbenchDiagnosis(
      summary: '所选 ${selected.length} 条剧本都已有关联素材。',
      detail: '可以先导出所选剧本 ZIP 做集中审阅，或转入单剧本工作台继续处理图片流程。',
      recommendedAction:
          ScriptBatchWorkbenchRecommendedAction.exportSelectedZip,
    );
  }

  return ScriptBatchWorkbenchDiagnosis(
    summary: '所选 ${selected.length} 条剧本仍有待抽取素材的项。',
    detail: '建议直接批量发起素材抽取，把当前选择转成后续图片和分镜流程可用的资产。',
    recommendedAction:
        ScriptBatchWorkbenchRecommendedAction.startExtractSelected,
  );
}
