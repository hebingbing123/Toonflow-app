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
  for (final match in kProductionScriptPlanAssetIdPattern.allMatches(flowData)) {
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
  if (studioContentContainsAny(normalized, kProductionAssetToolSignalTokens)) {
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

String _productionAssetTypeLabelL10n(AppLocalizations l10n, String value) {
  return switch (value) {
    'role' => l10n.agentWorkspaceProductionAssetTypeRole,
    'scene' => l10n.agentWorkspaceProductionAssetTypeScene,
    'tool' => l10n.agentWorkspaceProductionAssetTypeTool,
    _ => value,
  };
}

String summarizeProductionAssetScope(
  AppLocalizations l10n,
  Map<String, dynamic> args,
) {
  final ids = args['ids'];
  if (ids is List && ids.isNotEmpty) {
    final numericIds =
        ids.map(_parseLooseInt).where((id) => id > 0).toSet().toList()..sort();
    if (numericIds.isNotEmpty) {
      return l10n.agentWorkspaceProductionAssetScopeIds(numericIds.join(', '));
    }
  }
  final assetTypes = args['assetTypes'];
  if (assetTypes is List) {
    final labels = assetTypes
        .map(
          (value) =>
              value is String ? _productionAssetTypeLabelL10n(l10n, value) : '',
        )
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (labels.isNotEmpty) {
      return l10n.agentWorkspaceProductionAssetScopeTypes(labels.join('/'));
    }
  }
  return l10n.agentWorkspaceProductionAssetScopeCompact;
}

String summarizeProductionAssetReviewScope(
  AppLocalizations l10n,
  ProductionSupervisionReview review,
) {
  return summarizeProductionAssetScope(
    l10n,
    buildProductionReviewAssetArgs(review),
  );
}

String summarizeProductionAssetTypeScope(
  AppLocalizations l10n,
  List<String> assetTypes,
) {
  return summarizeProductionAssetScope(
    l10n,
    buildProductionAssetTypeReadArgs(assetTypes: assetTypes),
  );
}

String summarizeProductionAssetFocusIds(
  AppLocalizations l10n,
  List<int> assetIds, {
  int previewCount = 6,
}) {
  final ids = assetIds.where((id) => id > 0).toSet().toList()..sort();
  if (ids.isEmpty) return '';
  final visible = ids.take(previewCount).join(', ');
  if (ids.length <= previewCount) {
    return l10n.agentWorkspaceProductionAssetFocusIdsShort(visible);
  }
  return l10n.agentWorkspaceProductionAssetFocusIdsMore(visible, ids.length);
}

String summarizeProductionAssetReadiness(
  AppLocalizations l10n,
  List<Map<String, dynamic>> rows,
) {
  if (rows.isEmpty) return l10n.agentWorkspaceProductionAssetReadinessEmpty;
  final readyRoots = rows.where(productionFlowEntryHasMediaResult).length;
  final pendingDeriveCount = extractProductionPendingDeriveAssetIds(
    rows,
  ).length;
  final rootMissingCount = rows.length - readyRoots;
  final parts = <String>[
    l10n.agentWorkspaceProductionAssetReadinessRoots(readyRoots, rows.length),
  ];
  if (pendingDeriveCount > 0) {
    parts.add(
      l10n.agentWorkspaceProductionAssetReadinessDeriveGap(pendingDeriveCount),
    );
  }
  if (rootMissingCount > 0) {
    parts.add(
      l10n.agentWorkspaceProductionAssetReadinessRootMissing(rootMissingCount),
    );
  }
  return parts.join(l10n.agentWorkspaceProductionClauseJoiner);
}

String summarizeProductionStoryboardReadiness(
  AppLocalizations l10n,
  List<Map<String, dynamic>> rows,
) {
  if (rows.isEmpty) {
    return l10n.agentWorkspaceProductionStoryboardReadinessEmpty;
  }
  final targetCount = rows
      .where(productionStoryboardEntryNeedsImageGeneration)
      .length;
  final readyCount = rows.where((row) {
    return productionStoryboardEntryNeedsImageGeneration(row) &&
        productionFlowEntryHasMediaResult(row);
  }).length;
  final missingCount = extractProductionStoryboardMissingImageIds(rows).length;
  final pureTextCount = rows.length - targetCount;
  final parts = <String>[
    l10n.agentWorkspaceProductionStoryboardReadinessFrames(
      targetCount,
      readyCount,
    ),
  ];
  if (missingCount > 0) {
    parts.add(
      l10n.agentWorkspaceProductionStoryboardReadinessMissing(missingCount),
    );
  }
  if (pureTextCount > 0) {
    parts.add(
      l10n.agentWorkspaceProductionStoryboardReadinessTextOnly(pureTextCount),
    );
  }
  return parts.join(l10n.agentWorkspaceProductionClauseJoiner);
}

String summarizeProductionStoryboardTableCoverage(
  AppLocalizations l10n, {
  required int sampledRows,
  required int totalRows,
}) {
  if (sampledRows <= 0 && totalRows <= 0) {
    return l10n.agentWorkspaceProductionStoryboardTableCoverageUnread;
  }
  if (totalRows <= 0) {
    return l10n.agentWorkspaceProductionStoryboardTableCoverageRowsOnly(
      sampledRows,
    );
  }
  final remaining = (totalRows - sampledRows).clamp(0, totalRows);
  if (remaining > 0) {
    return l10n.agentWorkspaceProductionStoryboardTableCoverageWithPending(
      remaining,
      sampledRows,
      totalRows,
    );
  }
  return l10n.agentWorkspaceProductionStoryboardTableCoverageProgress(
    sampledRows,
    totalRows,
  );
}

String summarizeProductionPrimaryBlocker(
  List<ProductionWorkspaceStage> stages,
  AppLocalizations l10n,
) {
  if (stages.isEmpty) return '';
  final blocker = stages.firstWhere(
    (stage) => !stage.status.isResolvedForPrimaryBlocker,
    orElse: () => stages.last,
  );
  final explicitReason = _summarizeProductionBlockerReason(blocker, l10n);
  final statusLabel = blocker.status.localizedLabel(l10n);
  if (explicitReason.isNotEmpty) {
    return l10n.agentWorkspaceProductionBlockerHeadline(
      explicitReason,
      statusLabel,
      blocker.title,
    );
  }
  final normalizedDetail = blocker.detail
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final clippedDetail = normalizedDetail.length <= 72
      ? normalizedDetail
      : '${normalizedDetail.substring(0, 72)}...';
  return l10n.agentWorkspaceProductionBlockerHeadline(
    clippedDetail,
    statusLabel,
    blocker.title,
  );
}

String _summarizeProductionBlockerReason(
  ProductionWorkspaceStage stage,
  AppLocalizations l10n,
) {
  final sampled = stage.storyboardTableCoverageSampledRows;
  final total = stage.storyboardTableCoverageTotalRows;
  if (sampled != null && total != null && total > 0) {
    final coverage = summarizeProductionStoryboardTableCoverage(
      l10n,
      sampledRows: sampled,
      totalRows: total,
    );
    switch (stage.status) {
      case ProductionWorkspaceStageStatus.storyboardTableExpandRead:
        return l10n.agentWorkspaceProductionBlockerExpandTableWithCoverage(
          coverage,
        );
      case ProductionWorkspaceStageStatus.waitingStoryboardTableCoverage:
        return l10n
            .agentWorkspaceProductionBlockerExpandTableCoverageWithDigest(
              coverage,
            );
      default:
        break;
    }
  }
  final detail = stage.detail.replaceAll(RegExp(r'\s+'), ' ').trim();
  switch (stage.status) {
    case ProductionWorkspaceStageStatus.storyboardTableExpandRead:
      final coverage = _extractProductionCoverageDigest(detail, l10n);
      return coverage.isEmpty
          ? l10n.agentWorkspaceProductionBlockerExpandTable
          : l10n.agentWorkspaceProductionBlockerExpandTableWithCoverage(
              coverage,
            );
    case ProductionWorkspaceStageStatus.backfillScriptPlanFromTable:
      return l10n.agentWorkspaceProductionBlockerRefineScriptPlan;
    case ProductionWorkspaceStageStatus.waitingStoryboardTableCoverage:
      final coverage = _extractProductionCoverageDigest(detail, l10n);
      return coverage.isEmpty
          ? l10n.agentWorkspaceProductionBlockerExpandTableCoverage
          : l10n.agentWorkspaceProductionBlockerExpandTableCoverageWithDigest(
              coverage,
            );
    default:
      return '';
  }
}

String _extractProductionCoverageDigest(
  String detail,
  AppLocalizations l10n,
) {
  final ratioMatch = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(detail);
  if (ratioMatch == null) return '';
  final sampled = int.tryParse(ratioMatch.group(1)!) ?? 0;
  final total = int.tryParse(ratioMatch.group(2)!) ?? 0;
  final expandMatchZh = kProductionStoryboardExpandRowsZhPattern.firstMatch(detail);
  if (expandMatchZh != null) {
    final remaining = int.tryParse(expandMatchZh.group(1)!) ?? 0;
    return l10n.agentWorkspaceProductionStoryboardTableCoverageWithPending(
      remaining,
      sampled,
      total,
    );
  }
  final expandMatchEn = RegExp(
    r'(\d+)\s+rows\s+still\s+to\s+expand',
  ).firstMatch(detail);
  if (expandMatchEn != null) {
    final remaining = int.tryParse(expandMatchEn.group(1)!) ?? 0;
    return l10n.agentWorkspaceProductionStoryboardTableCoverageWithPending(
      remaining,
      sampled,
      total,
    );
  }
  if (detail.contains('Storyboard table: read') && detail.contains('rows')) {
    return l10n.agentWorkspaceProductionStoryboardTableCoverageProgress(
      sampled,
      total,
    );
  }
  return l10n.agentWorkspaceProductionStoryboardTableCoverageProgress(
    sampled,
    total,
  );
}

String productionStageDomainButtonLabel(
  ProductionWorkspaceStage stage,
  AppLocalizations l10n,
) {
  switch (stage.status) {
    case ProductionWorkspaceStageStatus.storyboardTableExpandRead:
    case ProductionWorkspaceStageStatus.waitingStoryboardTableCoverage:
      return l10n.agentWorkspaceProductionDomainExpandStoryboardTable;
    case ProductionWorkspaceStageStatus.backfillScriptPlanFromTable:
    case ProductionWorkspaceStageStatus.waitingScriptPlan:
    case ProductionWorkspaceStageStatus.waitingScriptPlanDepth:
      return l10n.agentWorkspaceProductionDomainReadScriptPlan;
    case ProductionWorkspaceStageStatus.suggestRefresh:
      return switch (stage.flowKey) {
        'scriptPlan' => l10n.agentWorkspaceProductionDomainRefreshScriptPlan,
        'assets' => switch (stage.refreshHint) {
          ProductionWorkspaceRefreshHint.rereadAffectedAssets =>
            l10n.agentWorkspaceProductionDomainRereadAffectedAssets,
          _ => l10n.agentWorkspaceProductionDomainRefreshAssets,
        },
        'storyboardTable' => switch (stage.refreshHint) {
          ProductionWorkspaceRefreshHint.rereadPartialStoryboardTable =>
            l10n.agentWorkspaceProductionDomainRereadPartialStoryboardTable,
          _ => l10n.agentWorkspaceProductionDomainRefreshStoryboardTable,
        },
        'storyboard' => switch (stage.refreshHint) {
          ProductionWorkspaceRefreshHint.rereadMissingFrameState =>
            l10n.agentWorkspaceProductionDomainRereadMissingFrames,
          _ => l10n.agentWorkspaceProductionDomainRefreshStoryboard,
        },
        _ => l10n.agentWorkspaceProductionDomainReadFlow,
      };
    default:
      return l10n.agentWorkspaceProductionDomainReadFlow;
  }
}

String productionStageSubAgentButtonLabel(
  ProductionWorkspaceStage stage,
  AppLocalizations l10n,
) {
  if (stage.status ==
          ProductionWorkspaceStageStatus.backfillScriptPlanFromTable ||
      stage.subAgentTool == 'run_sub_agent_director_plan') {
    return l10n.agentWorkspaceProductionSubAgentRefineDirectorPlan;
  }
  if (stage.subAgentTool == 'run_sub_agent_storyboard_table') {
    return l10n.agentWorkspaceProductionSubAgentFillStoryboardTable;
  }
  return l10n.agentWorkspaceProductionSubAgentAdvanceStage;
}

String productionRecipeDomainButtonLabel(
  ProductionWorkspaceRecipe recipe,
  AppLocalizations l10n,
) {
  switch (recipe.uiKind) {
    case ProductionWorkspaceRecipeUiKind.sampleStoryboardTable:
    case ProductionWorkspaceRecipeUiKind.previewStoryboardTableBeforeFrames:
      return l10n.agentWorkspaceProductionDomainExpandStoryboardTable;
    case ProductionWorkspaceRecipeUiKind.refineIntentBeforeTable:
    case ProductionWorkspaceRecipeUiKind.generic:
      break;
  }
  if (recipe.flowKey == 'scriptPlan' && recipe.domainTool == 'get_flowData') {
    return l10n.agentWorkspaceProductionDomainReadScriptPlan;
  }
  return l10n.agentWorkspaceProductionDomainReadFlow;
}

String productionRecipeSubAgentButtonLabel(
  ProductionWorkspaceRecipe recipe,
  AppLocalizations l10n,
) {
  if (recipe.subAgentTool == 'run_sub_agent_director_plan') {
    return l10n.agentWorkspaceProductionSubAgentRefineDirectorPlan;
  }
  if (recipe.subAgentTool == 'run_sub_agent_storyboard_table') {
    return l10n.agentWorkspaceProductionSubAgentFillStoryboardTable;
  }
  return l10n.agentWorkspaceProductionSubAgentAdvanceStage;
}

String summarizeProductionDiagnosisHeadline(
  List<ProductionWorkspaceRecipe> recipes,
  AppLocalizations l10n,
) {
  if (recipes.isEmpty) return '';
  final first = recipes.first;
  switch (first.uiKind) {
    case ProductionWorkspaceRecipeUiKind.refineIntentBeforeTable:
      return l10n.agentWorkspaceProductionFlowRecipeDiagnosisRefineIntentFirst;
    case ProductionWorkspaceRecipeUiKind.previewStoryboardTableBeforeFrames:
    case ProductionWorkspaceRecipeUiKind.sampleStoryboardTable:
      return l10n.agentWorkspaceProductionFlowRecipeDiagnosisExpandTableFirst;
    case ProductionWorkspaceRecipeUiKind.generic:
      return l10n.agentWorkspaceProductionFlowRecipeDiagnosisCheapestFirst;
  }
}

String summarizeAppliedProductionRecipeStatus(
  ProductionWorkspaceRecipe recipe,
  AppLocalizations l10n,
) {
  switch (recipe.uiKind) {
    case ProductionWorkspaceRecipeUiKind.refineIntentBeforeTable:
      return l10n.agentWorkspaceProductionRecipeAppliedFollowRefine(
        recipe.title,
      );
    case ProductionWorkspaceRecipeUiKind.previewStoryboardTableBeforeFrames:
    case ProductionWorkspaceRecipeUiKind.sampleStoryboardTable:
      return l10n.agentWorkspaceProductionRecipeAppliedFollowExpandTable(
        recipe.title,
      );
    case ProductionWorkspaceRecipeUiKind.generic:
      return l10n.agentWorkspaceProductionRecipeAppliedGeneric(recipe.title);
  }
}

String summarizeAppliedProductionStageStatus(
  ProductionWorkspaceStage stage,
  AppLocalizations l10n,
) {
  switch (stage.status) {
    case ProductionWorkspaceStageStatus.backfillScriptPlanFromTable:
      return l10n.agentWorkspaceProductionAppliedRefineDirectorPlan(
        stage.title,
      );
    case ProductionWorkspaceStageStatus.storyboardTableExpandRead:
    case ProductionWorkspaceStageStatus.waitingStoryboardTableCoverage:
      return l10n.agentWorkspaceProductionAppliedExpandStoryboardTable(
        stage.title,
      );
    default:
      return l10n.agentWorkspaceProductionAppliedStageGeneric(stage.title);
  }
}

String buildProductionScriptPlanExecutionHint(
  AppLocalizations l10n,
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
  final joined = compactSections.join(
    l10n.agentWorkspaceProductionSentenceJoinerSemicolon,
  );
  return l10n.agentWorkspaceProductionPromptScriptPlanExecutionHint(joined);
}

String buildProductionAssetReviewPrompt(
  AppLocalizations l10n,
  ProductionSupervisionReview review,
) {
  final args = buildProductionReviewAssetArgs(review);
  final scope = summarizeProductionAssetScope(l10n, args);
  final summary = review.summary.trim();
  final priority = summary.isEmpty
      ? ''
      : l10n.agentWorkspaceProductionAssetReviewPromptPriority(summary);
  if (args['ids'] case final List ids when ids.isNotEmpty) {
    final normalizedIds =
        ids.map(_parseLooseInt).where((id) => id > 0).toSet().toList()..sort();
    return l10n.agentWorkspaceProductionAssetReviewPromptFocused(
      normalizedIds.length,
      priority,
    );
  }
  return l10n.agentWorkspaceProductionAssetReviewPromptScoped(priority, scope);
}

String buildProductionAssetGenerationPrompt({
  required AppLocalizations l10n,
  required List<int> assetIds,
  String? summary,
  String? executionHint,
}) {
  final ids = assetIds.where((id) => id > 0).toSet().toList()..sort();
  final normalizedSummary = summary?.trim() ?? '';
  final priority = normalizedSummary.isEmpty
      ? ''
      : l10n.agentWorkspaceProductionPromptProductionPrioritySummary(
          normalizedSummary,
        );
  final normalizedExecutionHint = executionHint?.trim() ?? '';
  final execution = normalizedExecutionHint.isEmpty
      ? ''
      : l10n.agentWorkspaceProductionPromptExecutionConstraint(
          normalizedExecutionHint,
        );
  if (ids.isEmpty) {
    return l10n.agentWorkspaceProductionStagePromptAssetsGenerateNoIds(
      priority,
      execution,
    );
  }
  return l10n.agentWorkspaceProductionStagePromptAssetsGenerateFocused(
    ids.length,
    priority,
    execution,
  );
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
