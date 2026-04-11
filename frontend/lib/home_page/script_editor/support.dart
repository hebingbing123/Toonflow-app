import '../../rust_api.dart';

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

LegacyScriptsGetScriptApiItem? findScriptContextByLegacyId(
  Iterable<LegacyScriptsGetScriptApiItem> rows,
  int legacyId,
) {
  for (final row in rows) {
    if (row.legacyId == legacyId) {
      return row;
    }
  }
  return null;
}

ScriptExtractStatePollRow? findScriptExtractStateByLegacyId(
  Iterable<ScriptExtractStatePollRow> rows,
  int legacyId,
) {
  for (final row in rows) {
    if (row.legacyId == legacyId) {
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

ScriptWorkbenchDiagnosis diagnoseScriptWorkbench({
  LegacyScriptsGetScriptApiItem? scriptContext,
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
      scriptContext?.relatedAssets ?? const <LegacyScriptRelatedAssetBrief>[];

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
  required Iterable<LegacyScriptsGetScriptApiItem> previewRows,
}) {
  final selected = selectedIds.toList(growable: false);
  if (selected.isEmpty) {
    return const ScriptBatchWorkbenchDiagnosis(
      summary: '还没有选择要处理的剧本。',
      detail: '先读取剧本上下文或填写目标剧本 id，再执行批量导出、轮询或素材抽取。',
      recommendedAction: ScriptBatchWorkbenchRecommendedAction.syncContext,
    );
  }

  final previewById = <int, LegacyScriptsGetScriptApiItem>{
    for (final row in previewRows) row.legacyId: row,
  };
  final scriptById = <int, ScriptBrief>{
    for (final row in scripts) row.legacyId: row,
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

String summarizeRelatedScriptAssets(
  Iterable<LegacyScriptRelatedAssetBrief> assets, {
  int maxItems = 4,
}) {
  final trimmed = assets
      .map((asset) => asset.name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (trimmed.isEmpty) {
    return '未关联素材';
  }
  final visible = trimmed.take(maxItems).join('、');
  if (trimmed.length <= maxItems) {
    return visible;
  }
  return '$visible 等 ${trimmed.length} 项';
}

String formatBinarySize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
}

List<int> parseLegacyIdSelection(String raw) {
  final seen = <int>{};
  final values = <int>[];
  for (final token in raw.split(RegExp(r'[^0-9]+'))) {
    if (token.isEmpty) {
      continue;
    }
    final id = int.tryParse(token);
    if (id == null || id <= 0 || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    values.add(id);
  }
  return values;
}

String encodeLegacyIdSelection(Iterable<int> ids) {
  return ids.map((id) => id.toString()).join(',');
}

List<ScriptBrief> syncScriptExtractStates(
  Iterable<ScriptBrief> scripts,
  Iterable<ScriptExtractStatePollRow> rows,
) {
  final byLegacyId = <int, ScriptExtractStatePollRow>{
    for (final row in rows) row.legacyId: row,
  };
  return scripts
      .map((script) {
        final next = byLegacyId[script.legacyId];
        if (next == null) {
          return script;
        }
        return ScriptBrief(
          legacyId: script.legacyId,
          name: script.name,
          extractState: next.extractState,
        );
      })
      .toList(growable: false);
}

List<LegacyScriptsGetScriptApiItem> syncScriptPreviewExtractStates(
  Iterable<LegacyScriptsGetScriptApiItem> rows,
  Iterable<ScriptExtractStatePollRow> updates,
) {
  final byLegacyId = <int, ScriptExtractStatePollRow>{
    for (final row in updates) row.legacyId: row,
  };
  return rows
      .map((row) {
        final next = byLegacyId[row.legacyId];
        if (next == null) {
          return row;
        }
        return LegacyScriptsGetScriptApiItem(
          legacyId: row.legacyId,
          name: row.name,
          content: row.content,
          extractState: next.extractState,
          errorReason: next.errorReason ?? row.errorReason,
          createTime: row.createTime,
          relatedAssets: row.relatedAssets,
        );
      })
      .toList(growable: false);
}

List<BatchAddScriptItemV1> buildBatchAddScriptItems({
  required int count,
  required int startingIndex,
  required String prefix,
  required String scriptData,
}) {
  return List<BatchAddScriptItemV1>.generate(
    count,
    (index) => BatchAddScriptItemV1(
      scriptName: '$prefix ${startingIndex + index}',
      scriptData: scriptData,
    ),
    growable: false,
  );
}
