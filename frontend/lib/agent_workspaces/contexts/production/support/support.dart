part of '../support.dart';

class ProductionWorkspaceRecipe {
  const ProductionWorkspaceRecipe({
    required this.title,
    required this.detail,
    required this.flowKey,
    this.domainTool,
    this.domainArgs,
    this.subAgentTool,
    this.subAgentArgs,
    this.prompt,
  });

  final String title;
  final String detail;
  final String flowKey;
  final String? domainTool;
  final Map<String, dynamic>? domainArgs;
  final String? subAgentTool;
  final Map<String, dynamic>? subAgentArgs;
  final String? prompt;
}

class ProductionWorkspaceStage {
  const ProductionWorkspaceStage({
    required this.title,
    required this.flowKey,
    required this.statusLabel,
    required this.detail,
    this.domainTool,
    this.domainArgs,
    this.subAgentTool,
    this.subAgentArgs,
    this.prompt,
  });

  final String title;
  final String flowKey;
  final String statusLabel;
  final String detail;
  final String? domainTool;
  final Map<String, dynamic>? domainArgs;
  final String? subAgentTool;
  final Map<String, dynamic>? subAgentArgs;
  final String? prompt;
}

class ProductionSupervisionReview {
  const ProductionSupervisionReview({
    required this.target,
    required this.grade,
    required this.severeCount,
    required this.mediumCount,
    required this.minorCount,
    required this.nextAction,
    required this.summary,
    required this.assetIds,
    required this.assetTypes,
    required this.storyboardIds,
  });

  final String target;
  final String grade;
  final int severeCount;
  final int mediumCount;
  final int minorCount;
  final String nextAction;
  final String summary;
  final List<int> assetIds;
  final List<String> assetTypes;
  final List<int> storyboardIds;
}

class ProductionWorkspaceArgumentSuggestion {
  const ProductionWorkspaceArgumentSuggestion({
    required this.label,
    required this.payload,
  });

  final String label;
  final Map<String, dynamic> payload;
}

bool productionFlowEntryHasMediaResult(Map<String, dynamic> entry) {
  final raw =
      entry['src'] ?? entry['url'] ?? entry['imageUrl'] ?? entry['videoUrl'];
  return raw is String && raw.trim().isNotEmpty;
}

bool productionStoryboardEntryNeedsImageGeneration(Map<String, dynamic> entry) {
  final raw = entry['shouldGenerateImage'];
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
  }
  return true;
}

List<int> extractProductionStoryboardMissingImageIds(Object? flowData) {
  if (flowData is! List) return const <int>[];
  final ids = <int>{};
  for (final row in flowData.whereType<Map<String, dynamic>>()) {
    if (!productionStoryboardEntryNeedsImageGeneration(row) ||
        productionFlowEntryHasMediaResult(row)) {
      continue;
    }
    final rawId =
        row['id'] ??
        row['numeric_id'] ??
        row['numericId'] ??
        row['storyboardId'];
    if (rawId is num && rawId.toInt() > 0) {
      ids.add(rawId.toInt());
    }
  }
  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

List<int> extractProductionActionCandidateIds({
  required String? selectedTool,
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
  Map<String, dynamic>? toolArguments,
}) {
  final normalizedSelectedTool = selectedTool?.trim() ?? '';
  final normalizedToolName = toolName?.trim() ?? '';
  final normalizedKey = suggestedFlowKey?.trim() ?? '';
  if (result is! Map<String, dynamic>) {
    return const <int>[];
  }

  final review = parseProductionSupervisionReview(result);
  if (normalizedToolName == 'run_sub_agent_production_supervision' &&
      review != null) {
    switch (normalizedSelectedTool) {
      case 'generate_storyboard':
        if (review.nextAction == 'generate_storyboard' &&
            review.storyboardIds.isNotEmpty) {
          return review.storyboardIds;
        }
        return const <int>[];
      case 'generate_deriveAsset':
        if (review.nextAction == 'check_assets' && review.assetIds.isNotEmpty) {
          return review.assetIds;
        }
        return const <int>[];
      default:
        return const <int>[];
    }
  }

  if (normalizedToolName == 'generate_deriveAsset') {
    return _extractToolScopedIds(result['assetIds']);
  }

  if (normalizedToolName == 'generate_storyboard') {
    return _extractToolScopedIds(result['storyboardIds']);
  }

  final promptScopedIds = _extractPromptScopedIds(
    selectedTool: normalizedSelectedTool,
    toolName: normalizedToolName,
    toolArguments: toolArguments,
  );
  if (promptScopedIds.isNotEmpty) {
    return promptScopedIds;
  }

  Object? data = result['data'];
  if (normalizedToolName == 'get_flowData') {
    switch (normalizedSelectedTool) {
      case 'generate_deriveAsset':
        if (normalizedKey != 'assets') return const <int>[];
        return _extractDeriveAssetIds(data);
      case 'generate_storyboard':
        if (normalizedKey != 'storyboard') return const <int>[];
        final missingIds = extractProductionStoryboardMissingImageIds(data);
        if (missingIds.isNotEmpty) return missingIds;
        return _extractEntityIds(data);
      default:
        return const <int>[];
    }
  }

  if (data is Map<String, dynamic>) {
    switch (normalizedSelectedTool) {
      case 'generate_deriveAsset':
        return _extractDeriveAssetIds(data['assets']);
      case 'generate_storyboard':
        final storyboard = data['storyboard'];
        final missingIds = extractProductionStoryboardMissingImageIds(
          storyboard,
        );
        if (missingIds.isNotEmpty) return missingIds;
        return _extractEntityIds(storyboard);
      default:
        return const <int>[];
    }
  }

  return const <int>[];
}

ProductionSupervisionReview? parseProductionSupervisionReview(Object? result) {
  if (result is! Map<String, dynamic>) return null;
  final review = result['review'];
  if (review is! Map<String, dynamic>) return null;
  final target = (review['target'] as String?)?.trim() ?? '';
  final grade = (review['grade'] as String?)?.trim() ?? '';
  final nextAction = (review['nextAction'] as String?)?.trim() ?? '';
  final summary = (review['summary'] as String?)?.trim() ?? '';
  if (target.isEmpty || grade.isEmpty || nextAction.isEmpty) {
    return null;
  }
  return ProductionSupervisionReview(
    target: target,
    grade: grade,
    severeCount: _parseLooseInt(review['severeCount']),
    mediumCount: _parseLooseInt(review['mediumCount']),
    minorCount: _parseLooseInt(review['minorCount']),
    nextAction: nextAction,
    summary: summary,
    assetIds: _parseReviewAssetIds(review['assetIds']),
    assetTypes: _parseReviewAssetTypes(review['assetTypes']),
    storyboardIds: _parseReviewIds(review['storyboardIds']),
  );
}

int _parseLooseInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

List<int> _parseReviewAssetIds(Object? value) {
  return _parseReviewIds(value);
}

List<String> _parseReviewAssetTypes(Object? value) {
  final rawValues = switch (value) {
    List<dynamic> values => values,
    String text => text.split(','),
    _ => const <Object?>[],
  };
  final types = rawValues
      .map(_normalizeProductionAssetType)
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList();
  types.sort(
    (left, right) => _productionAssetTypeOrder(
      left,
    ).compareTo(_productionAssetTypeOrder(right)),
  );
  return types;
}

List<int> _parseReviewIds(Object? value) {
  if (value is List) {
    final ids = value
        .map(_parseLooseInt)
        .where((id) => id > 0)
        .toSet()
        .toList();
    ids.sort();
    return ids;
  }
  if (value is String) {
    final ids = value
        .split(',')
        .map((entry) => _parseLooseInt(entry))
        .where((id) => id > 0)
        .toSet()
        .toList();
    ids.sort();
    return ids;
  }
  return const <int>[];
}

Map<String, dynamic> buildProductionReviewAssetArgs(
  ProductionSupervisionReview review,
) {
  if (review.assetIds.isNotEmpty) {
    return buildProductionAssetReadArgs(ids: review.assetIds);
  }
  if (review.assetTypes.isNotEmpty) {
    return buildProductionAssetTypeReadArgs(assetTypes: review.assetTypes);
  }
  return buildProductionAssetReadArgs(ids: review.assetIds);
}

Map<String, dynamic> buildProductionReviewStoryboardArgs(
  ProductionSupervisionReview review,
) {
  return buildProductionStoryboardReviewArgs(ids: review.storyboardIds);
}

Map<String, dynamic> buildProductionReviewStoryboardGenerationArgs(
  ProductionSupervisionReview review,
) {
  return buildProductionStoryboardGenerationArgs(ids: review.storyboardIds);
}

Map<String, dynamic> buildProductionReviewStoryboardTableArgs(
  ProductionSupervisionReview review,
) {
  return buildProductionStoryboardTableReadArgs(ids: review.storyboardIds);
}

Map<String, dynamic> buildProductionScriptReviewArgs({
  ProductionSupervisionReview? review,
}) {
  final focusWindow = buildProductionStoryboardScriptFocusWindow(
    review?.storyboardIds ?? const <int>[],
  );
  return <String, dynamic>{
    'key': 'script',
    'lineStart': focusWindow.lineStart,
    'lineEnd': focusWindow.lineEnd,
    'maxChars': focusWindow.maxChars,
  };
}

class ProductionScriptReadWindow {
  const ProductionScriptReadWindow({
    required this.lineStart,
    required this.lineEnd,
    required this.maxChars,
  });

  final int lineStart;
  final int lineEnd;
  final int maxChars;
}

class ProductionStoryboardScriptFocusWindow {
  const ProductionStoryboardScriptFocusWindow({
    required this.lineStart,
    required this.lineEnd,
    required this.maxChars,
  });

  final int lineStart;
  final int lineEnd;
  final int maxChars;
}

ProductionScriptReadWindow buildProductionPlanningScriptWindow() {
  return const ProductionScriptReadWindow(
    lineStart: 1,
    lineEnd: 48,
    maxChars: 1400,
  );
}

Map<String, dynamic> buildProductionPlanningScriptArgs() {
  final window = buildProductionPlanningScriptWindow();
  return <String, dynamic>{
    'key': 'script',
    'lineStart': window.lineStart,
    'lineEnd': window.lineEnd,
    'maxChars': window.maxChars,
  };
}

String summarizeProductionPlanningScriptWindow() {
  final window = buildProductionPlanningScriptWindow();
  return '剧本 ${window.lineStart}-${window.lineEnd} 行（<=${window.maxChars} 字）';
}

String summarizeProductionStoryboardFocusIds(
  List<int> storyboardIds, {
  int previewCount = 6,
}) {
  final ids = storyboardIds.where((id) => id > 0).toSet().toList()..sort();
  if (ids.isEmpty) return '';
  final visible = ids.take(previewCount).join(', ');
  if (ids.length <= previewCount) {
    return '镜头 #$visible';
  }
  return '镜头 #$visible 等 ${ids.length} 个';
}

String summarizeProductionStoryboardScriptWindow(List<int> storyboardIds) {
  final ids = storyboardIds.where((id) => id > 0).toSet().toList()..sort();
  if (ids.isEmpty) return '';
  final focusWindow = buildProductionStoryboardScriptFocusWindow(ids);
  return '剧本 ${focusWindow.lineStart}-${focusWindow.lineEnd} 行（<=${focusWindow.maxChars} 字）';
}

String summarizeProductionStoryboardTableFocus(List<int> storyboardIds) {
  final focus = summarizeProductionStoryboardFocusIds(storyboardIds);
  if (focus.isEmpty) return '';
  return '分镜表仅回看$focus对应行';
}

String summarizeProductionStoryboardReviewScope(List<int> storyboardIds) {
  final tableFocus = summarizeProductionStoryboardTableFocus(storyboardIds);
  final scriptWindow = summarizeProductionStoryboardScriptWindow(storyboardIds);
  final pieces = <String>[
    if (tableFocus.isNotEmpty) tableFocus,
    if (scriptWindow.isNotEmpty) '剧本仅回看$scriptWindow',
  ];
  return pieces.join('；');
}

String buildProductionStoryboardPromptScope(
  List<int> storyboardIds, {
  required String fallback,
}) {
  final ids = storyboardIds.where((id) => id > 0).toSet().toList()..sort();
  if (ids.isEmpty) return fallback;
  return '优先处理这 ${ids.length} 个镜头';
}

String buildProductionStoryboardPromptContextHint(List<int> storyboardIds) {
  final ids = storyboardIds.where((id) => id > 0).toSet().toList()..sort();
  if (ids.isEmpty) {
    return '如需核对依据，先只回看同批 storyboardTable 行和局部剧本窗口。';
  }
  final tableFocus = summarizeProductionStoryboardFocusIds(ids);
  final scriptWindow = summarizeProductionStoryboardScriptWindow(ids);
  final pieces = <String>[
    if (tableFocus.isNotEmpty) '先只回看$tableFocus对应的 storyboardTable 行',
    if (scriptWindow.isNotEmpty) '剧本仅回看$scriptWindow',
  ];
  if (pieces.isEmpty) {
    return '如需核对依据，先只回看同批 storyboardTable 行和局部剧本窗口。';
  }
  return '如需核对依据，${pieces.join('，')}。';
}

String buildProductionStoryboardAssetHint(List<int> assetIds) {
  final ids = assetIds.where((id) => id > 0).toSet().toList()..sort();
  if (ids.isEmpty) return '';
  return '如需核对素材，仅看这 ${ids.length} 个关联资产。';
}

String buildProductionStoryboardGenerationPrompt({
  required List<int> storyboardIds,
  List<int> assetIds = const <int>[],
  String? summary,
}) {
  final scope = buildProductionStoryboardPromptScope(
    storyboardIds,
    fallback: '优先只补缺少画面结果的镜头',
  );
  final contextHint = buildProductionStoryboardPromptContextHint(storyboardIds);
  final assetHint = buildProductionStoryboardAssetHint(assetIds);
  final normalizedSummary = summary?.trim() ?? '';
  final summaryLine = normalizedSummary.isEmpty ? '' : '注意：$normalizedSummary';
  return '$scope，不要重跑已有结果或 shouldGenerateImage=false 的镜头。$contextHint$assetHint$summaryLine';
}

String buildProductionStoryboardTableRevisionPrompt(
  ProductionSupervisionReview review,
) {
  final summary = review.summary.trim();
  final scope = buildProductionStoryboardPromptScope(
    review.storyboardIds,
    fallback: '优先修订当前审核聚焦的分镜表问题',
  );
  final contextHint = buildProductionStoryboardPromptContextHint(
    review.storyboardIds,
  );
  final assetHint = buildProductionStoryboardAssetHint(review.assetIds);
  final summaryLine = summary.isEmpty ? '' : '优先解决：$summary';
  return '$scope 对应的 storyboardTable 行，保持其余行不动。$contextHint$assetHint$summaryLine';
}

ProductionStoryboardScriptFocusWindow
buildProductionStoryboardScriptFocusWindow(List<int> storyboardIds) {
  final ids = storyboardIds.where((id) => id > 0).toSet().toList()..sort();
  if (ids.isEmpty) {
    return const ProductionStoryboardScriptFocusWindow(
      lineStart: 1,
      lineEnd: 60,
      maxChars: 1400,
    );
  }

  final focusCount = ids.length;
  final minId = ids.first;
  final lineStart = ((minId - 2).clamp(0, 9999) * 6) + 1;
  final lineBudget = (focusCount * 8 + 16).clamp(32, 56);
  final maxChars = (focusCount * 120 + 680).clamp(920, 1600);
  return ProductionStoryboardScriptFocusWindow(
    lineStart: lineStart,
    lineEnd: lineStart + lineBudget - 1,
    maxChars: maxChars,
  );
}
