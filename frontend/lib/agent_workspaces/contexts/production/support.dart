class ProductionWorkspaceRecipe {
  const ProductionWorkspaceRecipe({
    required this.title,
    required this.detail,
    required this.flowKey,
    this.domainTool,
    this.domainArgs,
    this.subAgentTool,
    this.prompt,
  });

  final String title;
  final String detail;
  final String flowKey;
  final String? domainTool;
  final Map<String, dynamic>? domainArgs;
  final String? subAgentTool;
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
    this.prompt,
  });

  final String title;
  final String flowKey;
  final String statusLabel;
  final String detail;
  final String? domainTool;
  final Map<String, dynamic>? domainArgs;
  final String? subAgentTool;
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
  return '优先处理镜头 ids=${ids.join(',')}';
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

String buildProductionStoryboardGenerationPrompt({
  required List<int> storyboardIds,
  String? summary,
}) {
  final scope = buildProductionStoryboardPromptScope(
    storyboardIds,
    fallback: '优先只补缺少画面结果的镜头',
  );
  final contextHint = buildProductionStoryboardPromptContextHint(storyboardIds);
  final normalizedSummary = summary?.trim() ?? '';
  final summaryLine = normalizedSummary.isEmpty ? '' : '注意：$normalizedSummary';
  return '$scope，不要重跑已有结果或 shouldGenerateImage=false 的镜头。$contextHint$summaryLine';
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
  final summaryLine = summary.isEmpty ? '' : '优先解决：$summary';
  return '$scope 对应的 storyboardTable 行，保持其余行不动。$contextHint$summaryLine';
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

Map<String, dynamic> buildProductionFlowAssetArgs(Object? flowData) {
  final ids = extractProductionReferencedAssetIds(flowData);
  return buildProductionAssetReadArgs(ids: ids);
}

Map<String, dynamic> buildProductionScriptPlanAssetArgs(Object? flowData) {
  final ids = extractProductionScriptPlanAssetIds(flowData);
  if (ids.isNotEmpty) {
    return buildProductionAssetReadArgs(ids: ids);
  }
  final assetTypes = extractProductionScriptPlanAssetTypes(flowData);
  return buildProductionAssetTypeReadArgs(assetTypes: assetTypes);
}

Map<String, dynamic> buildProductionAssetReadArgs({
  List<int> ids = const <int>[],
}) {
  if (ids.isEmpty) {
    return _productionAssetsCompactArgs();
  }
  return <String, dynamic>{
    'key': 'assets',
    'ids': ids,
    'fields': _productionAssetFields(),
  };
}

Map<String, dynamic> buildProductionAssetTypeReadArgs({
  List<String> assetTypes = const <String>[],
}) {
  final normalizedTypes = assetTypes
      .map(_normalizeProductionAssetType)
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList();
  normalizedTypes.sort(
    (left, right) => _productionAssetTypeOrder(
      left,
    ).compareTo(_productionAssetTypeOrder(right)),
  );
  if (normalizedTypes.isEmpty) {
    return _productionAssetsCompactArgs();
  }
  return <String, dynamic>{
    'key': 'assets',
    'assetTypes': normalizedTypes,
    'fields': _productionAssetFields(),
    'limit': normalizedTypes.contains('tool') ? 18 : 12,
  };
}

List<int> extractProductionReferencedAssetIds(Object? flowData) {
  final ids = <int>{};

  void collectFromRows(Object? rows) {
    if (rows is! List) return;
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final values = row['associateAssetsIds'];
      if (values is! List) continue;
      for (final value in values) {
        final numericId = _parseLooseInt(value);
        if (numericId > 0) {
          ids.add(numericId);
        }
      }
    }
  }

  void collectFromMarkdown(String text) {
    final parsed = parseProductionStoryboardTableMarkdown(text);
    for (final row in parsed) {
      final values = row['associateAssetsIds'];
      if (values is! List) continue;
      for (final value in values) {
        final numericId = _parseLooseInt(value);
        if (numericId > 0) {
          ids.add(numericId);
        }
      }
    }
  }

  if (flowData is List) {
    collectFromRows(flowData);
  } else if (flowData is Map<String, dynamic>) {
    collectFromRows(flowData['rows']);
  } else if (flowData is String) {
    collectFromMarkdown(flowData);
  }

  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

List<int> extractProductionScriptPlanAssetIds(Object? flowData) {
  if (flowData is! String) return const <int>[];
  final ids = <int>{};
  for (final match in RegExp(
    r'(?:资产|asset)\s*[#：:\s]?\s*([\d\s,，、]+)',
    caseSensitive: false,
  ).allMatches(flowData)) {
    final raw = match.group(1) ?? '';
    for (final token in raw.split(RegExp(r'[\s,，、]+'))) {
      final numericId = int.tryParse(token.trim());
      if (numericId != null && numericId > 0) {
        ids.add(numericId);
      }
    }
  }
  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

List<String> extractProductionScriptPlanAssetTypes(Object? flowData) {
  if (flowData is! String) {
    return const <String>['role', 'scene'];
  }
  final normalized = flowData.replaceAll(RegExp(r'</?scriptPlan>'), '');
  final assetTypes = <String>{'role', 'scene'};
  final toolSignals = <Pattern>[
    '道具',
    '物件',
    '兵器',
    '武器',
    '法器',
    '信物',
    '令牌',
    '玉佩',
    '佩剑',
    'tool',
    'prop',
  ];
  if (toolSignals.any((signal) => normalized.contains(signal))) {
    assetTypes.add('tool');
  }
  final sortedTypes = assetTypes.toList()
    ..sort(
      (left, right) => _productionAssetTypeOrder(
        left,
      ).compareTo(_productionAssetTypeOrder(right)),
    );
  return sortedTypes;
}

String summarizeProductionAssetScope(Map<String, dynamic> args) {
  final ids = args['ids'];
  if (ids is List && ids.isNotEmpty) {
    final numericIds =
        ids.map(_parseLooseInt).where((id) => id > 0).toSet().toList()..sort();
    if (numericIds.isNotEmpty) {
      return '资产 #${numericIds.join(', ')}';
    }
  }
  final assetTypes = args['assetTypes'];
  if (assetTypes is List) {
    final labels = assetTypes
        .map((value) => value is String ? _productionAssetTypeLabel(value) : '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (labels.isNotEmpty) {
      return '${labels.join('/')}资产';
    }
  }
  return '紧凑资产摘要';
}

String summarizeProductionAssetReviewScope(ProductionSupervisionReview review) {
  return summarizeProductionAssetScope(buildProductionReviewAssetArgs(review));
}

String summarizeProductionAssetTypeScope(List<String> assetTypes) {
  return summarizeProductionAssetScope(
    buildProductionAssetTypeReadArgs(assetTypes: assetTypes),
  );
}

String summarizeProductionAssetFocusIds(
  List<int> assetIds, {
  int previewCount = 6,
}) {
  final ids = assetIds.where((id) => id > 0).toSet().toList()..sort();
  if (ids.isEmpty) return '';
  final visible = ids.take(previewCount).join(', ');
  if (ids.length <= previewCount) {
    return '资产 #$visible';
  }
  return '资产 #$visible 等 ${ids.length} 项';
}

String buildProductionAssetReviewPrompt(ProductionSupervisionReview review) {
  final args = buildProductionReviewAssetArgs(review);
  final scope = summarizeProductionAssetScope(args);
  final summary = review.summary.trim();
  final summaryLine = summary.isEmpty ? '' : '优先解决：$summary';
  if (args['ids'] case final List ids when ids.isNotEmpty) {
    final normalizedIds =
        ids.map(_parseLooseInt).where((id) => id > 0).toSet().toList()..sort();
    return '请优先只核对资产 ids=${normalizedIds.join(',')} 是否支撑当前导演规划；仅补必要缺口，不扩读无关素材。$summaryLine';
  }
  return '请先核对$scope是否支撑当前导演规划；信息不足时再最小补读，不要整包扩读 assets。$summaryLine';
}

String buildProductionAssetGenerationPrompt({
  required List<int> assetIds,
  String? summary,
}) {
  final ids = assetIds.where((id) => id > 0).toSet().toList()..sort();
  final normalizedSummary = summary?.trim() ?? '';
  final summaryLine = normalizedSummary.isEmpty
      ? ''
      : '优先解决：$normalizedSummary';
  if (ids.isEmpty) {
    return '请基于最新 assets flow 判断哪些衍生资产仍缺图，只对真实缺口发起最小可行生成，不要重跑已有结果或扩读无关素材。$summaryLine';
  }
  return '请优先只核对并生成资产 ids=${ids.join(',')}；若其中已有结果则跳过，只补剩余缺口，不要扩读无关 assets。$summaryLine';
}

List<int> extractProductionStoryboardIds(Object? flowData) {
  final ids = <int>{};

  void collectFromRows(Object? rows) {
    if (rows is! List) return;
    ids.addAll(_extractEntityIds(rows));
  }

  void collectFromMarkdown(String text) {
    final parsed = parseProductionStoryboardTableMarkdown(text);
    ids.addAll(_extractEntityIds(parsed));
  }

  if (flowData is List) {
    collectFromRows(flowData);
  } else if (flowData is Map<String, dynamic>) {
    collectFromRows(flowData['rows']);
  } else if (flowData is String) {
    collectFromMarkdown(flowData);
  }

  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

int countProductionStoryboardTableRows(Object? flowData) {
  if (flowData is Map<String, dynamic>) {
    final totalRows = _parseLooseInt(flowData['totalRows']);
    if (totalRows > 0) return totalRows;
    final rows = flowData['rows'];
    if (rows is List) return rows.length;
  }
  if (flowData is String) {
    return parseProductionStoryboardTableMarkdown(flowData).length;
  }
  return 0;
}

int countProductionScriptPlanSections(Object? flowData) {
  if (flowData is! String) return 0;
  final matches = RegExp(r'[①②③④⑤⑥]').allMatches(flowData).length;
  return matches.clamp(0, 6);
}

List<String> summarizeProductionScriptPlanSections(
  Object? flowData, {
  int maxSections = 4,
}) {
  if (flowData is! String) return const <String>[];
  final text = flowData.replaceAll(RegExp(r'</?scriptPlan>'), '').trim();
  if (text.isEmpty) return const <String>[];

  final summaries = <String>[];
  String? currentHeading;
  String? currentDetail;

  void flushSection() {
    final heading = currentHeading?.trim() ?? '';
    if (heading.isEmpty) return;
    final detail = currentDetail?.trim() ?? '';
    if (detail.isEmpty || detail == heading) {
      summaries.add(heading);
    } else {
      final compactDetail = detail.replaceAll(RegExp(r'\s+'), ' ').trim();
      final clipped = compactDetail.length <= 54
          ? compactDetail
          : '${compactDetail.substring(0, 54)}...';
      summaries.add('$heading：$clipped');
    }
  }

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (RegExp(r'^[①②③④⑤⑥]').hasMatch(line)) {
      flushSection();
      currentHeading = line;
      currentDetail = null;
      continue;
    }
    if (currentHeading != null && currentDetail == null) {
      currentDetail = line;
    }
  }
  flushSection();
  if (summaries.isEmpty) return const <String>[];
  return summaries.take(maxSections).toList(growable: false);
}

List<Map<String, dynamic>> parseProductionStoryboardTableMarkdown(String text) {
  final tableLines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('|') && line.endsWith('|'))
      .toList(growable: false);
  if (tableLines.length < 3) {
    return const <Map<String, dynamic>>[];
  }

  final headers = _splitMarkdownTableRow(
    tableLines.first,
  ).map(_normalizeStoryboardTableColumn).toList(growable: false);
  if (headers.isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  final rows = <Map<String, dynamic>>[];
  for (final line in tableLines.skip(2)) {
    final cells = _splitMarkdownTableRow(line);
    if (cells.length != headers.length) continue;
    final row = <String, dynamic>{};
    for (var index = 0; index < headers.length; index += 1) {
      final header = headers[index];
      final rawCell = cells[index].trim();
      if (header == 'associateAssetsIds') {
        row[header] = RegExp(r'\d+')
            .allMatches(rawCell)
            .map((match) => int.tryParse(match.group(0) ?? ''))
            .whereType<int>()
            .toList(growable: false);
      } else {
        row[header] = rawCell;
      }
    }
    rows.add(row);
  }
  return rows;
}

List<ProductionWorkspaceArgumentSuggestion>
buildProductionActionArgumentSuggestions({
  required String? selectedTool,
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
}) {
  final normalizedSelectedTool = selectedTool?.trim() ?? '';
  final flowData = _resolveProductionFlowData(
    toolName: toolName,
    suggestedFlowKey: suggestedFlowKey,
    result: result,
  );
  switch (normalizedSelectedTool) {
    case 'add_deriveAsset':
      return _buildAddDeriveAssetSuggestions(flowData);
    case 'del_deriveAsset':
      return _buildDeleteDeriveAssetSuggestions(flowData);
    case 'generate_deriveAsset':
      return _buildIdSuggestions(
        extractProductionActionCandidateIds(
          selectedTool: selectedTool,
          toolName: toolName,
          suggestedFlowKey: suggestedFlowKey,
          result: result,
        ),
      );
    case 'generate_storyboard':
      return _buildIdSuggestions(
        extractProductionActionCandidateIds(
          selectedTool: selectedTool,
          toolName: toolName,
          suggestedFlowKey: suggestedFlowKey,
          result: result,
        ),
      );
    default:
      return const <ProductionWorkspaceArgumentSuggestion>[];
  }
}

Object? _resolveProductionFlowData({
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
}) {
  if (result is! Map<String, dynamic>) {
    return null;
  }
  final normalizedToolName = toolName?.trim() ?? '';
  final normalizedKey = suggestedFlowKey?.trim() ?? '';
  final data = result['data'];
  if (normalizedToolName == 'get_flowData') {
    return switch (normalizedKey) {
      'assets' || 'storyboard' => data,
      _ => null,
    };
  }
  if (data is Map<String, dynamic>) {
    return data[normalizedKey];
  }
  return null;
}

List<ProductionWorkspaceArgumentSuggestion> _buildAddDeriveAssetSuggestions(
  Object? flowData,
) {
  if (flowData is! List) {
    return const <ProductionWorkspaceArgumentSuggestion>[];
  }
  final suggestions = <ProductionWorkspaceArgumentSuggestion>[];
  for (final row in flowData.whereType<Map<String, dynamic>>().take(3)) {
    final parentId = row['id'];
    if (parentId is! num) continue;
    final name = (row['name'] as String?)?.trim();
    suggestions.add(
      ProductionWorkspaceArgumentSuggestion(
        label: '新增到 #${parentId.toInt()}',
        payload: <String, dynamic>{
          'assetsId': parentId.toInt(),
          'id': null,
          'name': name == null || name.isEmpty ? '新衍生资产' : '$name-衍生',
          'desc': '',
        },
      ),
    );
  }
  return suggestions;
}

List<String> _productionAssetFields() => <String>[
  'id',
  'name',
  'type',
  'src',
  'flowId',
  'derive',
];

Map<String, dynamic> _productionAssetsCompactArgs() => <String, dynamic>{
  'key': 'assets',
  'fields': _productionAssetFields(),
  'limit': 24,
};

int _productionAssetTypeOrder(String value) {
  return switch (value) {
    'role' => 0,
    'scene' => 1,
    'tool' => 2,
    _ => 99,
  };
}

String _normalizeProductionAssetType(Object? value) {
  final normalized = switch (value) {
    String text => text.trim().toLowerCase(),
    _ => '',
  };
  return switch (normalized) {
    'role' || 'roles' || 'character' || 'characters' => 'role',
    'scene' || 'scenes' || 'location' || 'locations' => 'scene',
    'tool' || 'tools' || 'prop' || 'props' => 'tool',
    _ => '',
  };
}

String _productionAssetTypeLabel(String value) {
  return switch (value) {
    'role' => '角色',
    'scene' => '场景',
    'tool' => '道具',
    _ => value,
  };
}

List<String> productionStoryboardFields() => <String>[
  'id',
  'index',
  'duration',
  'prompt',
  'src',
  'state',
  'flowId',
  'associateAssetsIds',
  'shouldGenerateImage',
];

Map<String, dynamic> buildProductionStoryboardCompactArgs() =>
    <String, dynamic>{
      'key': 'storyboard',
      'fields': productionStoryboardFields(),
      'limit': 24,
    };

List<String> productionStoryboardTableFields() => <String>[
  'id',
  'description',
  'scene',
  'duration',
  'camera',
  'associateAssetsIds',
];

Map<String, dynamic> buildProductionStoryboardTableReadArgs({
  List<int> ids = const <int>[],
  int rowStart = 1,
  int rowCount = 8,
}) {
  final payload = <String, dynamic>{
    'key': 'storyboardTable',
    'fields': productionStoryboardTableFields(),
  };
  if (ids.isNotEmpty) {
    payload['ids'] = ids;
  } else {
    payload['rowStart'] = rowStart;
    payload['rowCount'] = rowCount;
  }
  return payload;
}

List<String> productionStoryboardReviewFields() => <String>[
  'id',
  'index',
  'duration',
  'src',
  'state',
  'associateAssetsIds',
  'shouldGenerateImage',
];

Map<String, dynamic> buildProductionStoryboardReviewArgs({
  List<int> ids = const <int>[],
}) {
  final payload = <String, dynamic>{
    'key': 'storyboard',
    'fields': productionStoryboardReviewFields(),
  };
  if (ids.isNotEmpty) {
    payload['ids'] = ids;
  } else {
    payload['limit'] = 12;
  }
  return payload;
}

List<String> productionStoryboardGenerationFields() => <String>[
  'id',
  'index',
  'src',
  'state',
  'associateAssetsIds',
  'shouldGenerateImage',
];

Map<String, dynamic> buildProductionStoryboardGenerationArgs({
  List<int> ids = const <int>[],
}) {
  final payload = <String, dynamic>{
    'key': 'storyboard',
    'fields': productionStoryboardGenerationFields(),
  };
  if (ids.isNotEmpty) {
    payload['ids'] = ids;
  } else {
    payload['limit'] = 12;
  }
  return payload;
}

List<ProductionWorkspaceArgumentSuggestion> _buildDeleteDeriveAssetSuggestions(
  Object? flowData,
) {
  if (flowData is! List) {
    return const <ProductionWorkspaceArgumentSuggestion>[];
  }
  final suggestions = <ProductionWorkspaceArgumentSuggestion>[];
  for (final row in flowData.whereType<Map<String, dynamic>>()) {
    final parentId = row['id'];
    if (parentId is! num) continue;
    final derive = row['derive'];
    if (derive is! List) continue;
    for (final child in derive.whereType<Map<String, dynamic>>()) {
      final deriveId = child['id'];
      if (deriveId is! num) continue;
      suggestions.add(
        ProductionWorkspaceArgumentSuggestion(
          label: '删除 #${deriveId.toInt()}',
          payload: <String, dynamic>{
            'assetsId': parentId.toInt(),
            'id': deriveId.toInt(),
          },
        ),
      );
      if (suggestions.length >= 3) {
        return suggestions;
      }
    }
  }
  return suggestions;
}

List<ProductionWorkspaceArgumentSuggestion> _buildIdSuggestions(List<int> ids) {
  if (ids.isEmpty) return const <ProductionWorkspaceArgumentSuggestion>[];
  return <ProductionWorkspaceArgumentSuggestion>[
    ProductionWorkspaceArgumentSuggestion(
      label: '填充首项',
      payload: <String, dynamic>{'ids': ids.take(1).toList(growable: false)},
    ),
    if (ids.length > 1)
      ProductionWorkspaceArgumentSuggestion(
        label: '填充前 3 项',
        payload: <String, dynamic>{'ids': ids.take(3).toList(growable: false)},
      ),
    if (ids.length > 3)
      ProductionWorkspaceArgumentSuggestion(
        label: '填充全部',
        payload: <String, dynamic>{'ids': ids},
      ),
  ];
}

List<int> _extractDeriveAssetIds(Object? value) {
  if (value is! List) return const <int>[];
  final ids = <int>[];
  for (final row in value.whereType<Map<String, dynamic>>()) {
    final derive = row['derive'];
    if (derive is! List) continue;
    ids.addAll(_extractEntityIds(derive));
  }
  return ids;
}

List<int> extractProductionPendingDeriveAssetIds(Object? value) {
  if (value is! List) return const <int>[];
  final ids = <int>{};
  for (final row in value.whereType<Map<String, dynamic>>()) {
    final derive = row['derive'];
    if (derive is! List) continue;
    for (final child in derive.whereType<Map<String, dynamic>>()) {
      final childId = _parseLooseInt(
        child['id'] ??
            child['numeric_id'] ??
            child['numericId'] ??
            child['assetId'] ??
            child['assetsId'],
      );
      if (childId <= 0 || productionFlowEntryHasMediaResult(child)) {
        continue;
      }
      ids.add(childId);
    }
  }
  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

List<int> _extractEntityIds(Object? value) {
  if (value is! List) return const <int>[];
  final ids = <int>{};
  for (final row in value.whereType<Map<String, dynamic>>()) {
    final rawId =
        row['id'] ??
        row['numeric_id'] ??
        row['numericId'] ??
        row['storyboardId'] ??
        row['assetId'] ??
        row['assetsId'];
    final parsedId = _parseLooseInt(rawId);
    if (parsedId > 0) {
      ids.add(parsedId);
    }
  }
  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

List<int> _extractToolScopedIds(Object? value) {
  if (value is! List) return const <int>[];
  final ids = value.map(_parseLooseInt).where((id) => id > 0).toSet().toList();
  ids.sort();
  return ids;
}

List<String> _splitMarkdownTableRow(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) {
    return const <String>[];
  }
  return trimmed
      .substring(1, trimmed.length - 1)
      .split('|')
      .map((cell) => cell.trim())
      .toList(growable: false);
}

String _normalizeStoryboardTableColumn(String column) {
  switch (column.trim()) {
    case '序号':
    case 'id':
      return 'id';
    case '画面描述':
    case 'description':
      return 'description';
    case '场景':
    case 'scene':
      return 'scene';
    case '时长':
    case 'duration':
      return 'duration';
    case '景别':
    case 'camera':
      return 'camera';
    case '关联资产ID':
    case '关联资产Ids':
    case 'associateAssetsIds':
      return 'associateAssetsIds';
    default:
      return column.trim();
  }
}
