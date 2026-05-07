part of '../support.dart';

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

Map<String, dynamic> buildProductionScriptPlanSubAgentArgs(Object? flowData) {
  return _buildProductionSubAgentArgsFromAssetReadArgs(
    buildProductionScriptPlanAssetArgs(flowData),
  );
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

Map<String, dynamic> _buildProductionSubAgentArgsFromAssetReadArgs(
  Map<String, dynamic> args,
) {
  final ids = args['ids'];
  if (ids is List) {
    return buildProductionSubAgentArgs(
      assetIds: ids.map(_parseLooseInt).where((id) => id > 0).toList(),
    );
  }
  final assetTypes = args['assetTypes'];
  if (assetTypes is List) {
    return buildProductionSubAgentArgs(
      assetTypes: assetTypes.whereType<String>().toList(growable: false),
    );
  }
  return const <String, dynamic>{};
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

List<int> extractProductionReferencedAssetIdsForStoryboardIds(
  Object? flowData,
  List<int> storyboardIds,
) {
  final focusIds = storyboardIds.where((id) => id > 0).toSet();
  if (focusIds.isEmpty) {
    return extractProductionReferencedAssetIds(flowData);
  }

  final assetIds = <int>{};

  void collectFromRows(Object? rows) {
    if (rows is! List) return;
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final storyboardId = _parseLooseInt(
        row['id'] ??
            row['numeric_id'] ??
            row['numericId'] ??
            row['storyboardId'],
      );
      if (!focusIds.contains(storyboardId)) {
        continue;
      }
      final values = row['associateAssetsIds'];
      if (values is! List) continue;
      for (final value in values) {
        final numericId = _parseLooseInt(value);
        if (numericId > 0) {
          assetIds.add(numericId);
        }
      }
    }
  }

  void collectFromMarkdown(String text) {
    final parsed = parseProductionStoryboardTableMarkdown(text);
    collectFromRows(parsed);
  }

  if (flowData is List) {
    collectFromRows(flowData);
  } else if (flowData is Map<String, dynamic>) {
    collectFromRows(flowData['rows']);
  } else if (flowData is String) {
    collectFromMarkdown(flowData);
  }

  final sortedIds = assetIds.toList()..sort();
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

String summarizeProductionAssetReadiness(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '资产为空';
  final readyRoots = rows.where(productionFlowEntryHasMediaResult).length;
  final pendingDeriveCount = extractProductionPendingDeriveAssetIds(rows).length;
  final rootMissingCount = rows.length - readyRoots;
  final parts = <String>['主资产 $readyRoots/${rows.length} 已就绪'];
  if (pendingDeriveCount > 0) {
    parts.add('衍生缺口 $pendingDeriveCount 项');
  }
  if (rootMissingCount > 0) {
    parts.add('主资产待补 $rootMissingCount 项');
  }
  return parts.join('，');
}

String summarizeProductionStoryboardReadiness(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '分镜为空';
  final targetCount = rows.where(productionStoryboardEntryNeedsImageGeneration).length;
  final readyCount = rows.where((row) {
    return productionStoryboardEntryNeedsImageGeneration(row) &&
        productionFlowEntryHasMediaResult(row);
  }).length;
  final missingCount = extractProductionStoryboardMissingImageIds(rows).length;
  final pureTextCount = rows.length - targetCount;
  final parts = <String>['画面结果 $readyCount/$targetCount 已就绪'];
  if (missingCount > 0) {
    parts.add('待补帧 $missingCount 项');
  }
  if (pureTextCount > 0) {
    parts.add('纯文本 $pureTextCount 项');
  }
  return parts.join('，');
}

String summarizeProductionStoryboardTableCoverage({
  required int sampledRows,
  required int totalRows,
}) {
  if (sampledRows <= 0 && totalRows <= 0) {
    return '分镜表未读取';
  }
  if (totalRows <= 0) {
    return '分镜表已读 $sampledRows 行';
  }
  final remaining = (totalRows - sampledRows).clamp(0, totalRows);
  final parts = <String>['分镜表已读 $sampledRows/$totalRows 行'];
  if (remaining > 0) {
    parts.add('待展开 $remaining 行');
  }
  return parts.join('，');
}

String summarizeProductionPrimaryBlocker(List<ProductionWorkspaceStage> stages) {
  if (stages.isEmpty) return '';
  const resolvedStatuses = <String>{'已齐备', '已完成', '已抽样'};
  final blocker = stages.firstWhere(
    (stage) => !resolvedStatuses.contains(stage.statusLabel.trim()),
    orElse: () => stages.last,
  );
  final explicitReason = _summarizeProductionBlockerReason(blocker);
  if (explicitReason.isNotEmpty) {
    return '当前卡点：${blocker.title} · ${blocker.statusLabel}；$explicitReason';
  }
  final normalizedDetail = blocker.detail.replaceAll(RegExp(r'\s+'), ' ').trim();
  final clippedDetail = normalizedDetail.length <= 72
      ? normalizedDetail
      : '${normalizedDetail.substring(0, 72)}...';
  return '当前卡点：${blocker.title} · ${blocker.statusLabel}；$clippedDetail';
}

String _summarizeProductionBlockerReason(ProductionWorkspaceStage stage) {
  final status = stage.statusLabel.trim();
  final detail = stage.detail.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (status == '待扩读') {
    final coverage = _extractProductionCoverageDigest(detail);
    return coverage.isEmpty ? '先继续扩读关键分镜表窗口，再决定是否推进下游出图。' : '先继续扩读关键分镜表窗口；$coverage。';
  }
  if (status == '回补导演计划') {
    return '当前更缺导演计划里的分场景情绪/画面意图，先细化 scriptPlan 再拆分镜表。';
  }
  if (status == '等待分镜表完善') {
    final coverage = _extractProductionCoverageDigest(detail);
    return coverage.isEmpty ? '分镜表已有基础内容，但覆盖还不够，先补齐关键镜头表再推进 storyboard。' : '分镜表已有基础内容，但覆盖还不够；$coverage。';
  }
  return '';
}

String _extractProductionCoverageDigest(String detail) {
  final match = RegExp(r'分镜表已读 \d+/\d+ 行(?:，待展开 \d+ 行)?').firstMatch(detail);
  return match?.group(0) ?? '';
}

String productionStageDomainButtonLabel(ProductionWorkspaceStage stage) {
  final status = stage.statusLabel.trim();
  if (status == '待扩读' || status == '等待分镜表完善') {
    return '扩读分镜表';
  }
  if (status == '回补导演计划' ||
      status == '等待导演计划' ||
      status == '等待导演计划完善') {
    return '读取导演计划';
  }
  return '读取 flow';
}

String productionStageSubAgentButtonLabel(ProductionWorkspaceStage stage) {
  final status = stage.statusLabel.trim();
  if (status == '回补导演计划' ||
      stage.subAgentTool == 'run_sub_agent_director_plan') {
    return '细化导演计划';
  }
  if (stage.subAgentTool == 'run_sub_agent_storyboard_table') {
    return '补分镜表';
  }
  return '推进阶段';
}

String productionRecipeDomainButtonLabel(ProductionWorkspaceRecipe recipe) {
  final title = recipe.title.trim();
  if (title == '抽样读取分镜表' || title == '先看分镜表落地') {
    return '扩读分镜表';
  }
  if (recipe.flowKey == 'scriptPlan' && recipe.domainTool == 'get_flowData') {
    return '读取导演计划';
  }
  return '读取 flow';
}

String productionRecipeSubAgentButtonLabel(ProductionWorkspaceRecipe recipe) {
  final title = recipe.title.trim();
  if (title == '补足分场景意图' ||
      recipe.subAgentTool == 'run_sub_agent_director_plan') {
    return '细化导演计划';
  }
  if (recipe.subAgentTool == 'run_sub_agent_storyboard_table') {
    return '补分镜表';
  }
  return '运行子代理';
}

String summarizeProductionDiagnosisHeadline(
  List<ProductionWorkspaceRecipe> recipes,
) {
  if (recipes.isEmpty) return '';
  final first = recipes.first;
  final title = first.title.trim();
  if (title == '补足分场景意图') {
    return '当前更建议先细化导演计划里的分场景情绪/画面意图，再继续拆分分镜表。';
  }
  if (title == '先看分镜表落地' || title == '抽样读取分镜表') {
    return '当前更建议先扩读关键分镜表窗口，再决定是否推进 storyboard。';
  }
  return '当前建议按第一张卡开始推进，优先执行最靠前的低成本动作。';
}

String summarizeAppliedProductionRecipeStatus(ProductionWorkspaceRecipe recipe) {
  final title = recipe.title.trim();
  if (title == '补足分场景意图') {
    return '已应用任务建议：$title，下一步先细化导演计划。';
  }
  if (title == '先看分镜表落地' || title == '抽样读取分镜表') {
    return '已应用任务建议：$title，下一步先扩读关键分镜表窗口。';
  }
  return '已应用任务建议：$title';
}

String summarizeAppliedProductionStageStatus(ProductionWorkspaceStage stage) {
  final status = stage.statusLabel.trim();
  if (status == '回补导演计划') {
    return '已应用阶段动作：${stage.title}，下一步先细化导演计划。';
  }
  if (status == '待扩读' || status == '等待分镜表完善') {
    return '已应用阶段动作：${stage.title}，下一步先扩读关键分镜表窗口。';
  }
  return '已应用阶段动作：${stage.title}';
}

String buildProductionScriptPlanExecutionHint(
  Object? flowData, {
  int maxSections = 2,
}) {
  final sections = summarizeProductionScriptPlanSections(
    flowData,
    maxSections: maxSections,
  );
  if (sections.isEmpty) {
    return '';
  }
  final compactSections = sections
      .map((section) => section.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((section) => section.isNotEmpty)
      .toList(growable: false);
  if (compactSections.isEmpty) {
    return '';
  }
  return '承接 scriptPlan：${compactSections.join('；')}。人物情绪保持递进，避免生硬直述。';
}

String buildProductionAssetReviewPrompt(ProductionSupervisionReview review) {
  final args = buildProductionReviewAssetArgs(review);
  final scope = summarizeProductionAssetScope(args);
  final summary = review.summary.trim();
  final summaryLine = summary.isEmpty ? '' : '优先解决：$summary';
  if (args['ids'] case final List ids when ids.isNotEmpty) {
    final normalizedIds =
        ids.map(_parseLooseInt).where((id) => id > 0).toSet().toList()..sort();
    return '请优先只核对这 ${normalizedIds.length} 个资产是否支撑当前导演规划；仅补必要缺口，不扩读无关素材。$summaryLine';
  }
  return '请先核对$scope是否支撑当前导演规划；信息不足时再最小补读，不要整包扩读 assets。$summaryLine';
}

String buildProductionAssetGenerationPrompt({
  required List<int> assetIds,
  String? summary,
  String? executionHint,
}) {
  final ids = assetIds.where((id) => id > 0).toSet().toList()..sort();
  final normalizedSummary = summary?.trim() ?? '';
  final summaryLine = normalizedSummary.isEmpty
      ? ''
      : '优先解决：$normalizedSummary';
  final normalizedExecutionHint = executionHint?.trim() ?? '';
  final executionLine = normalizedExecutionHint.isEmpty
      ? ''
      : '执行约束：$normalizedExecutionHint';
  if (ids.isEmpty) {
    return '请基于最新 assets flow 判断哪些衍生资产仍缺图，只对真实缺口发起最小可行生成，不要重跑已有结果或扩读无关素材。$summaryLine$executionLine';
  }
  return '请优先只核对并生成这 ${ids.length} 个资产；若其中已有结果则跳过，只补剩余缺口，不要扩读无关 assets。$summaryLine$executionLine';
}

Map<String, dynamic> buildProductionSubAgentArgs({
  List<int> storyboardIds = const <int>[],
  List<int> assetIds = const <int>[],
  List<String> assetTypes = const <String>[],
}) {
  final payload = <String, dynamic>{};
  final normalizedStoryboardIds =
      storyboardIds.where((id) => id > 0).toSet().toList()..sort();
  final normalizedAssetIds = assetIds.where((id) => id > 0).toSet().toList()
    ..sort();
  final normalizedAssetTypes =
      assetTypes
          .map(_normalizeProductionAssetType)
          .where((entry) => entry.isNotEmpty)
          .toSet()
          .toList()
        ..sort(
          (left, right) => _productionAssetTypeOrder(
            left,
          ).compareTo(_productionAssetTypeOrder(right)),
        );
  if (normalizedStoryboardIds.isNotEmpty) {
    payload['storyboardIds'] = normalizedStoryboardIds;
  }
  if (normalizedAssetIds.isNotEmpty) {
    payload['assetIds'] = normalizedAssetIds;
  }
  if (normalizedAssetTypes.isNotEmpty) {
    payload['assetTypes'] = normalizedAssetTypes;
  }
  return payload;
}

Map<String, dynamic> buildProductionSuggestedSubAgentArgs({
  required String? subAgentTool,
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
  Map<String, dynamic>? toolArguments,
}) {
  final normalizedSubAgentTool = subAgentTool?.trim() ?? '';
  final normalizedToolName = toolName?.trim() ?? '';
  final normalizedFlowKey = suggestedFlowKey?.trim() ?? '';
  final review = parseProductionSupervisionReview(result);

  if (review != null) {
    switch (normalizedSubAgentTool) {
      case 'run_sub_agent_director_plan':
        return buildProductionSubAgentArgs(
          storyboardIds: review.storyboardIds,
          assetIds: review.assetIds,
          assetTypes: review.assetIds.isEmpty
              ? review.assetTypes
              : const <String>[],
        );
      case 'run_sub_agent_derive_assets':
      case 'run_sub_agent_generate_assets':
        return buildProductionReviewAssetSubAgentArgs(review);
      case 'run_sub_agent_storyboard_gen':
      case 'run_sub_agent_storyboard_panel':
      case 'run_sub_agent_storyboard_table':
        return buildProductionReviewStoryboardSubAgentArgs(review);
    }
  }

  switch (normalizedSubAgentTool) {
    case 'run_sub_agent_generate_assets':
      return _buildProductionGenerateAssetsSubAgentArgs(
        toolName: normalizedToolName,
        suggestedFlowKey: normalizedFlowKey,
        result: result,
        toolArguments: toolArguments,
      );
    case 'run_sub_agent_derive_assets':
      return _buildProductionDeriveAssetsSubAgentArgs(
        toolName: normalizedToolName,
        suggestedFlowKey: normalizedFlowKey,
        result: result,
      );
    case 'run_sub_agent_storyboard_gen':
    case 'run_sub_agent_storyboard_panel':
      return _buildProductionStoryboardSubAgentArgs(
        toolName: normalizedToolName,
        suggestedFlowKey: normalizedFlowKey,
        result: result,
        toolArguments: toolArguments,
      );
    case 'run_sub_agent_storyboard_table':
      return _buildProductionStoryboardTableSubAgentArgs(
        toolName: normalizedToolName,
        suggestedFlowKey: normalizedFlowKey,
        result: result,
        toolArguments: toolArguments,
      );
    case 'run_sub_agent_director_plan':
      return _buildProductionDirectorPlanSubAgentArgs(
        toolName: normalizedToolName,
        suggestedFlowKey: normalizedFlowKey,
        result: result,
      );
    default:
      return const <String, dynamic>{};
  }
}

Map<String, dynamic> buildProductionReviewAssetSubAgentArgs(
  ProductionSupervisionReview review,
) {
  return _buildProductionSubAgentArgsFromAssetReadArgs(
    buildProductionReviewAssetArgs(review),
  );
}

Map<String, dynamic> buildProductionReviewStoryboardSubAgentArgs(
  ProductionSupervisionReview review,
) {
  return buildProductionSubAgentArgs(
    storyboardIds: review.storyboardIds,
    assetIds: review.assetIds,
    assetTypes: review.assetIds.isEmpty ? review.assetTypes : const <String>[],
  );
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
