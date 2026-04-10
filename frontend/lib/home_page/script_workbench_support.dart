import '../rust_api.dart';

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

  final extractState = extractStateRow?.extractState ?? scriptContext?.extractState;
  final trimmedError = (
    extractStateRow?.errorReason ??
    scriptContext?.errorReason ??
    ''
  ).trim();
  final relatedAssets = scriptContext?.relatedAssets ?? const <LegacyScriptRelatedAssetBrief>[];

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
    detail:
        '已同步 ${relatedAssets.length} 条关联素材，可继续进入编辑图片工作台，或先导出 ZIP 做本地审阅。',
    recommendedAction: ScriptWorkbenchRecommendedAction.openEditImageWorkbench,
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
