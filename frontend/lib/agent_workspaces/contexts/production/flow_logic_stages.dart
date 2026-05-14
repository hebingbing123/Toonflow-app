part of 'flow_logic.dart';

List<ProductionWorkspaceStage> buildProductionWorkspaceStages({
  required AppLocalizations l10n,
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
  Map<String, dynamic>? toolArguments,
}) {
  final normalizedTool = toolName?.trim() ?? '';
  final normalizedKey = suggestedFlowKey?.trim() ?? '';
  final review = parseProductionSupervisionReview(result);
  final flowSnapshot = _resolveProductionWorkspaceFlowSnapshot(
    toolName: toolName,
    suggestedFlowKey: suggestedFlowKey,
    result: result,
  );
  final activeKey = _resolveProductionStageActiveKey(
    toolName: normalizedTool,
    suggestedFlowKey: normalizedKey,
    review: review,
  );

  return <ProductionWorkspaceStage>[
    _buildScriptPlanStage(
      l10n: l10n,
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
      review: review,
    ),
    _buildAssetsStage(
      l10n: l10n,
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
      result: result,
      review: review,
      toolArguments: toolArguments,
    ),
    _buildStoryboardTableStage(
      l10n: l10n,
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
      review: review,
      toolArguments: toolArguments,
    ),
    _buildStoryboardStage(
      l10n: l10n,
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
      review: review,
      suggestedFlowKey: suggestedFlowKey,
      result: result,
      toolArguments: toolArguments,
    ),
  ];
}

Map<String, Object?> _resolveProductionWorkspaceFlowSnapshot({
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
}) {
  final snapshot = <String, Object?>{};
  if (result is! Map<String, dynamic>) {
    return snapshot;
  }
  final normalizedTool = toolName?.trim() ?? '';
  final normalizedKey = suggestedFlowKey?.trim() ?? '';
  final data = result['data'];
  if (normalizedTool == 'get_flowData' && normalizedKey.isNotEmpty) {
    snapshot[normalizedKey] = data;
    return snapshot;
  }
  if (data is Map<String, dynamic>) {
    for (final key in <String>[
      'scriptPlan',
      'assets',
      'storyboardTable',
      'storyboard',
    ]) {
      if (data.containsKey(key)) {
        snapshot[key] = data[key];
      }
    }
  }
  return snapshot;
}

String? _resolveProductionStageActiveKey({
  required String toolName,
  required String suggestedFlowKey,
  required ProductionSupervisionReview? review,
}) {
  if (toolName == 'get_flowData' && suggestedFlowKey.isNotEmpty) {
    return suggestedFlowKey;
  }
  if (toolName == 'run_sub_agent_production_supervision') {
    if (review?.nextAction == 'check_assets') {
      return 'assets';
    }
    return review?.target;
  }
  return switch (toolName) {
    'add_deriveAsset' ||
    'del_deriveAsset' ||
    'generate_deriveAsset' => 'assets',
    'generate_storyboard' => 'storyboard',
    'run_sub_agent_director_plan' => 'scriptPlan',
    'run_sub_agent_derive_assets' ||
    'run_sub_agent_generate_assets' => 'assets',
    'run_sub_agent_storyboard_table' => 'storyboardTable',
    'run_sub_agent_storyboard_gen' ||
    'run_sub_agent_storyboard_panel' => 'storyboard',
    _ => null,
  };
}

ProductionWorkspaceStage _buildScriptPlanStage({
  required AppLocalizations l10n,
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
  required ProductionSupervisionReview? review,
}) {
  if (review != null && review.target == 'scriptPlan') {
    final planningScriptArgs = buildProductionPlanningScriptArgs();
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
      flowKey: 'scriptPlan',
      status: ProductionWorkspaceStageStatus.fromSupervisionReview(review),
      detail: _reviewDetail(l10n, review),
      domainTool: switch (review.nextAction) {
        'check_assets' || 'revise_scriptPlan' => 'get_flowData',
        _ => null,
      },
      domainArgs: switch (review.nextAction) {
        'check_assets' => buildProductionReviewAssetArgs(review),
        'revise_scriptPlan' => planningScriptArgs,
        _ => null,
      },
      subAgentTool: review.nextAction == 'revise_scriptPlan'
          ? 'run_sub_agent_director_plan'
          : null,
      prompt: review.nextAction == 'revise_scriptPlan'
          ? l10n.agentWorkspaceProductionStagePromptReviseScriptPlan(
              review.summary,
            )
          : null,
    );
  }
  final data = flowSnapshot['scriptPlan'];
  if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
        flowKey: 'scriptPlan',
        status: ProductionWorkspaceStageStatus.pendingGenerate,
        detail: l10n.agentWorkspaceProductionStageDetailScriptPlanEmpty,
        subAgentTool: 'run_sub_agent_director_plan',
        prompt: l10n.agentWorkspaceProductionStagePromptScriptPlanEmpty,
      );
    }
    final sectionCount = countProductionScriptPlanSections(trimmed);
    final sectionLine = sectionCount > 0
        ? l10n.agentWorkspaceProductionStageDetailScriptPlanSectionLine(
            sectionCount,
          )
        : '';
    final scriptWindow = summarizeProductionPlanningScriptWindow(l10n);
    if (!_productionScriptPlanAdvanceReady(trimmed)) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
        flowKey: 'scriptPlan',
        status: ProductionWorkspaceStageStatus.pendingRefineScriptPlan,
        detail: l10n.agentWorkspaceProductionStageDetailScriptPlanRefine(
          sectionLine,
          trimmed.length,
        ),
        subAgentTool: 'run_sub_agent_director_plan',
        prompt: l10n.agentWorkspaceProductionStagePromptScriptPlanRefine,
      );
    }
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
      flowKey: 'scriptPlan',
      status: ProductionWorkspaceStageStatus.pendingReview,
      detail: l10n.agentWorkspaceProductionStageDetailScriptPlanReview(
        sectionLine,
        trimmed.length,
        scriptWindow,
      ),
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: l10n.agentWorkspaceProductionStagePromptScriptPlanReview,
    );
  }
  if (activeKey == 'scriptPlan' || toolName == 'run_sub_agent_director_plan') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
      flowKey: 'scriptPlan',
      status: ProductionWorkspaceStageStatus.suggestRefresh,
      detail: l10n.agentWorkspaceProductionStageDetailScriptPlanRefresh,
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  return ProductionWorkspaceStage(
    title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
    flowKey: 'scriptPlan',
    status: ProductionWorkspaceStageStatus.pendingRead,
    detail: l10n.agentWorkspaceProductionStageDetailScriptPlanPendingRead,
    domainTool: 'get_flowData',
    domainArgs: _scriptPlanCompactArgs(),
  );
}

ProductionWorkspaceStage _buildAssetsStage({
  required AppLocalizations l10n,
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
  required Object? result,
  required ProductionSupervisionReview? review,
  required Map<String, dynamic>? toolArguments,
}) {
  if (review != null && review.nextAction == 'check_assets') {
    final assetArgs = buildProductionReviewAssetArgs(review);
    final assetScope = summarizeProductionAssetScope(l10n, assetArgs);
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.fromSupervisionReview(review),
      detail: l10n.agentWorkspaceProductionStageDetailAssetsAfterReview(
        _reviewDetail(l10n, review),
        assetScope,
      ),
      domainTool: 'get_flowData',
      domainArgs: assetArgs,
    );
  }
  final data = flowSnapshot['assets'];
  final scriptPlanReady = _productionScriptPlanReady(
    flowSnapshot['scriptPlan'],
  );
  final scriptPlanAdvanceReady = _productionScriptPlanAdvanceReady(
    flowSnapshot['scriptPlan'],
  );
  final executionHint = buildProductionScriptPlanExecutionHint(
    l10n,
    flowSnapshot['scriptPlan'],
  );
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    if (rows.isEmpty) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowAssets,
        flowKey: 'assets',
        status: ProductionWorkspaceStageStatus.pendingAssetPlan,
        detail: l10n.agentWorkspaceProductionStageDetailAssetsEmpty,
        subAgentTool: 'run_sub_agent_derive_assets',
        prompt: l10n.agentWorkspaceProductionStagePromptAssetsEmpty,
      );
    }
    final readyCount = rows.where((row) {
      return productionFlowEntryHasMediaResult(row);
    }).length;
    final missingCount = rows.length - readyCount;
    final pendingDeriveIds = extractProductionPendingDeriveAssetIds(rows);
    final pendingScope = summarizeProductionAssetFocusIds(
      l10n,
      pendingDeriveIds,
    );
    final readiness = summarizeProductionAssetReadiness(l10n, rows);
    if (missingCount > 0) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowAssets,
        flowKey: 'assets',
        status: ProductionWorkspaceStageStatus.needsAssetImages,
        detail: pendingScope.isEmpty
            ? l10n.agentWorkspaceProductionStageDetailAssetsMissingGeneric(
                missingCount,
                readiness,
                rows.length,
              )
            : l10n.agentWorkspaceProductionStageDetailAssetsMissingFocused(
                pendingScope,
                readiness,
                rows.length,
              ),
        subAgentTool: 'run_sub_agent_generate_assets',
        subAgentArgs: buildProductionSubAgentArgs(assetIds: pendingDeriveIds),
        prompt: buildProductionAssetGenerationPrompt(
          l10n: l10n,
          assetIds: pendingDeriveIds,
          executionHint: executionHint,
        ),
      );
    }
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.assetsReady,
      detail: l10n.agentWorkspaceProductionStageDetailAssetsReady(
        rows.length,
        readiness,
      ),
      domainTool: 'get_flowData',
      domainArgs: _assetsCompactArgs(),
    );
  }
  final storyboardTableAssetArgs = buildProductionFlowAssetArgs(
    flowSnapshot['storyboardTable'],
  );
  if (storyboardTableAssetArgs.containsKey('ids')) {
    final ids = storyboardTableAssetArgs['ids'] as List<int>;
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.assetsScopedFromRefs,
      detail: l10n.agentWorkspaceProductionStageDetailAssetsScopedTable(
        ids.length,
      ),
      domainTool: 'get_flowData',
      domainArgs: storyboardTableAssetArgs,
    );
  }
  final storyboardAssetArgs = buildProductionFlowAssetArgs(
    flowSnapshot['storyboard'],
  );
  if (storyboardAssetArgs.containsKey('ids')) {
    final ids = storyboardAssetArgs['ids'] as List<int>;
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.assetsScopedFromRefs,
      detail: l10n.agentWorkspaceProductionStageDetailAssetsScopedStoryboard(
        ids.length,
      ),
      domainTool: 'get_flowData',
      domainArgs: storyboardAssetArgs,
    );
  }
  final scriptPlanAssetArgs = buildProductionScriptPlanAssetArgs(
    flowSnapshot['scriptPlan'],
  );
  final scriptPlanAssetScope = summarizeProductionAssetScope(
    l10n,
    scriptPlanAssetArgs,
  );
  if (scriptPlanReady &&
      !scriptPlanAdvanceReady &&
      activeKey != 'assets' &&
      toolName != 'generate_deriveAsset' &&
      toolName != 'add_deriveAsset' &&
      toolName != 'del_deriveAsset' &&
      toolName != 'run_sub_agent_derive_assets' &&
      toolName != 'run_sub_agent_generate_assets') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.waitingScriptPlanDepth,
      detail: l10n.agentWorkspaceProductionStageDetailAssetsWaitScriptDepth,
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  if (flowSnapshot['scriptPlan'] is String) {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.assetsNarrowedFromScriptPlan,
      detail: l10n.agentWorkspaceProductionStageDetailAssetsNarrowedScriptPlan(
        scriptPlanAssetScope,
      ),
      domainTool: 'get_flowData',
      domainArgs: scriptPlanAssetArgs,
    );
  }
  if (!scriptPlanReady &&
      activeKey != 'assets' &&
      toolName != 'generate_deriveAsset' &&
      toolName != 'add_deriveAsset' &&
      toolName != 'del_deriveAsset' &&
      toolName != 'run_sub_agent_derive_assets' &&
      toolName != 'run_sub_agent_generate_assets') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.waitingScriptPlan,
      detail: l10n.agentWorkspaceProductionStageDetailAssetsWaitScript,
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  if (activeKey == 'assets' ||
      toolName == 'generate_deriveAsset' ||
      toolName == 'add_deriveAsset' ||
      toolName == 'del_deriveAsset' ||
      toolName == 'run_sub_agent_derive_assets' ||
      toolName == 'run_sub_agent_generate_assets') {
    final refreshArgs =
        toolName == 'generate_deriveAsset' ||
            toolName == 'run_sub_agent_generate_assets'
        ? buildProductionAssetReadArgs(
            ids: extractProductionActionCandidateIds(
              selectedTool: 'generate_deriveAsset',
              toolName: toolName,
              suggestedFlowKey: 'assets',
              result: result,
              toolArguments: toolArguments,
            ),
          )
        : _assetsCompactArgs();
    final narrowAssetRefresh =
        (toolName == 'generate_deriveAsset' ||
            toolName == 'run_sub_agent_generate_assets') &&
        refreshArgs.containsKey('ids');
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.suggestRefresh,
      refreshHint: narrowAssetRefresh
          ? ProductionWorkspaceRefreshHint.rereadAffectedAssets
          : ProductionWorkspaceRefreshHint.refreshAssetsSnapshot,
      detail: narrowAssetRefresh
          ? l10n.agentWorkspaceProductionStageDetailAssetsRefreshNarrow
          : l10n.agentWorkspaceProductionStageDetailAssetsRefreshWide,
      domainTool: 'get_flowData',
      domainArgs: refreshArgs,
    );
  }
  return ProductionWorkspaceStage(
    title: l10n.agentWorkspaceProductionStageFlowAssets,
    flowKey: 'assets',
    status: ProductionWorkspaceStageStatus.pendingRead,
    detail: l10n.agentWorkspaceProductionStageDetailAssetsPendingRead,
    domainTool: 'get_flowData',
    domainArgs: _assetsCompactArgs(),
  );
}

ProductionWorkspaceStage _buildStoryboardTableStage({
  required AppLocalizations l10n,
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
  required ProductionSupervisionReview? review,
  required Map<String, dynamic>? toolArguments,
}) {
  if (review != null && review.target == 'storyboardTable') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: ProductionWorkspaceStageStatus.fromSupervisionReview(review),
      detail: _reviewDetail(l10n, review),
      domainTool: switch (review.nextAction) {
        'check_script' => 'get_flowData',
        'revise_storyboardTable' => 'get_flowData',
        _ => null,
      },
      domainArgs: switch (review.nextAction) {
        'check_script' => buildProductionScriptReviewArgs(review: review),
        'revise_storyboardTable' => buildProductionReviewStoryboardTableArgs(
          review,
        ),
        _ => null,
      },
      subAgentTool: switch (review.nextAction) {
        'revise_storyboardTable' => 'run_sub_agent_storyboard_table',
        _ => null,
      },
      subAgentArgs: switch (review.nextAction) {
        'revise_storyboardTable' => buildProductionSubAgentArgs(
          storyboardIds: review.storyboardIds,
          assetIds: review.assetIds,
          assetTypes: review.assetTypes,
        ),
        _ => null,
      },
      prompt: switch (review.nextAction) {
        'revise_storyboardTable' =>
          l10n.agentWorkspaceProductionStagePromptStoryboardTableReviseLead(
            buildProductionStoryboardTableRevisionPrompt(l10n, review),
          ),
        _ => null,
      },
    );
  }
  final data = flowSnapshot['storyboardTable'];
  final scriptPlanReady = _productionScriptPlanReady(
    flowSnapshot['scriptPlan'],
  );
  final scriptPlanAdvanceReady = _productionScriptPlanAdvanceReady(
    flowSnapshot['scriptPlan'],
  );
  final scriptPlanStoryboardReady = _productionScriptPlanStoryboardReady(
    flowSnapshot['scriptPlan'],
  );
  if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
        flowKey: 'storyboardTable',
        status: ProductionWorkspaceStageStatus.pendingGenerate,
        detail: l10n.agentWorkspaceProductionStageDetailStoryboardTableEmpty,
        subAgentTool: 'run_sub_agent_storyboard_table',
        prompt: l10n.agentWorkspaceProductionStagePromptStoryboardTableEmpty,
      );
    }
    final rowCount = countProductionStoryboardTableRows(trimmed);
    final assetCount = extractProductionReferencedAssetIds(trimmed).length;
    final digest = <String>[
      if (rowCount > 0)
        l10n.agentWorkspaceProductionStageDigestStoryboardTableRows(rowCount),
      if (assetCount > 0)
        l10n.agentWorkspaceProductionStageDigestStoryboardTableAssets(
          assetCount,
        ),
    ].join(l10n.agentWorkspaceProductionClauseJoiner);
    final rowDigest = digest.isEmpty
        ? ''
        : '${l10n.agentWorkspaceProductionClauseJoiner}$digest${l10n.agentWorkspaceProductionClauseJoiner}';
    final coverage = summarizeProductionStoryboardTableCoverage(
      l10n,
      sampledRows: rowCount,
      totalRows: rowCount,
    );
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: ProductionWorkspaceStageStatus.pendingReview,
      detail: l10n.agentWorkspaceProductionStageDetailStoryboardTableString(
        rowDigest,
        trimmed.length,
        coverage,
      ),
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: l10n.agentWorkspaceProductionStagePromptStoryboardTableReview,
      storyboardTableCoverageSampledRows: rowCount,
      storyboardTableCoverageTotalRows: rowCount,
    );
  }
  if (data is Map<String, dynamic>) {
    final rowCount = _readInt(data['rowCount']);
    final totalRows = _readInt(data['totalRows']);
    final advanceReady = _productionStoryboardTableAdvanceReady(data);
    final tableStatus = advanceReady
        ? ProductionWorkspaceStageStatus.storyboardTableSampled
        : scriptPlanReady && !scriptPlanStoryboardReady
        ? ProductionWorkspaceStageStatus.backfillScriptPlanFromTable
        : ProductionWorkspaceStageStatus.storyboardTableExpandRead;
    final coverage = summarizeProductionStoryboardTableCoverage(
      l10n,
      sampledRows: rowCount,
      totalRows: totalRows,
    );
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: tableStatus,
      detail: advanceReady
          ? l10n.agentWorkspaceProductionStageDetailStoryboardTableWindowReady(
              rowCount,
              totalRows,
              coverage,
            )
          : scriptPlanReady && !scriptPlanStoryboardReady
          ? l10n.agentWorkspaceProductionStageDetailStoryboardTableWindowBackfill(
              rowCount,
              totalRows,
              coverage,
            )
          : l10n.agentWorkspaceProductionStageDetailStoryboardTableWindowExpand(
              rowCount,
              totalRows,
              coverage,
            ),
      domainTool: 'get_flowData',
      domainArgs: scriptPlanReady && !scriptPlanStoryboardReady
          ? _scriptPlanCompactArgs()
          : buildProductionStoryboardTableReadArgs(),
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: l10n.agentWorkspaceProductionStagePromptStoryboardTableReview,
      storyboardTableCoverageSampledRows: rowCount,
      storyboardTableCoverageTotalRows: totalRows,
    );
  }
  if (!scriptPlanReady &&
      activeKey != 'storyboardTable' &&
      toolName != 'run_sub_agent_storyboard_table') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: ProductionWorkspaceStageStatus.waitingScriptPlan,
      detail: l10n.agentWorkspaceProductionStageDetailStoryboardTableWaitScript,
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  if (scriptPlanReady &&
      !scriptPlanAdvanceReady &&
      activeKey != 'storyboardTable' &&
      toolName != 'run_sub_agent_storyboard_table') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: ProductionWorkspaceStageStatus.waitingScriptPlanDepth,
      detail: l10n
          .agentWorkspaceProductionStageDetailStoryboardTableWaitScriptDepth,
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  if (activeKey == 'storyboardTable' ||
      toolName == 'run_sub_agent_storyboard_table') {
    final affectedIds = toolName == 'run_sub_agent_storyboard_table'
        ? extractProductionStoryboardPromptScopeIds(toolName, toolArguments)
        : const <int>[];
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: ProductionWorkspaceStageStatus.suggestRefresh,
      refreshHint: affectedIds.isEmpty
          ? ProductionWorkspaceRefreshHint.refreshStoryboardTableSnapshot
          : ProductionWorkspaceRefreshHint.rereadPartialStoryboardTable,
      detail: affectedIds.isEmpty
          ? l10n.agentWorkspaceProductionStageDetailStoryboardTableRefreshWide
          : l10n.agentWorkspaceProductionStageDetailStoryboardTableRefreshNarrow(
              affectedIds.join(', '),
            ),
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(ids: affectedIds),
    );
  }
  return ProductionWorkspaceStage(
    title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
    flowKey: 'storyboardTable',
    status: ProductionWorkspaceStageStatus.pendingRead,
    detail: l10n.agentWorkspaceProductionStageDetailStoryboardTablePendingRead,
    domainTool: 'get_flowData',
    domainArgs: buildProductionStoryboardTableReadArgs(),
  );
}

ProductionWorkspaceStage _buildStoryboardStage({
  required AppLocalizations l10n,
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
  required ProductionSupervisionReview? review,
  required String? suggestedFlowKey,
  required Object? result,
  required Map<String, dynamic>? toolArguments,
}) {
  final scriptPlanReady = _productionScriptPlanReady(
    flowSnapshot['scriptPlan'],
  );
  final scriptPlanAdvanceReady = _productionScriptPlanAdvanceReady(
    flowSnapshot['scriptPlan'],
  );
  final storyboardTableReady = _productionStoryboardTableReady(
    flowSnapshot['storyboardTable'],
  );
  final storyboardTableAdvanceReady = _productionStoryboardTableAdvanceReady(
    flowSnapshot['storyboardTable'],
  );
  final scriptPlanStoryboardReady = _productionScriptPlanStoryboardReady(
    flowSnapshot['scriptPlan'],
  );
  final executionHint = buildProductionScriptPlanExecutionHint(
    l10n,
    flowSnapshot['scriptPlan'],
  );
  if (review != null &&
      (review.nextAction == 'check_storyboard' ||
          review.nextAction == 'generate_storyboard')) {
    final storyboardArgs = review.nextAction == 'generate_storyboard'
        ? buildProductionReviewStoryboardGenerationArgs(review)
        : buildProductionReviewStoryboardArgs(review);
    final storyboardIds = review.storyboardIds;
    final reviewScope = summarizeProductionStoryboardReviewScope(
      l10n,
      storyboardIds,
    );
    final scopeLine = storyboardIds.isEmpty
        ? (review.nextAction == 'generate_storyboard'
              ? l10n.agentWorkspaceProductionStageDetailStoryboardSupervisionGenerateScopeEmpty
              : l10n.agentWorkspaceProductionStageDetailStoryboardSupervisionCheckScopeEmpty)
        : l10n.agentWorkspaceProductionStageDetailStoryboardSupervisionScoped(
            storyboardIds.length,
            reviewScope.isEmpty
                ? ''
                : l10n.agentWorkspaceProductionSupervisionReviewScopeAppend(
                    reviewScope,
                  ),
          );
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: review.nextAction == 'generate_storyboard'
          ? ProductionWorkspaceStageStatus.storyboardFramesPending
          : ProductionWorkspaceStageStatus.storyboardPendingVerify,
      detail: scopeLine.isEmpty
          ? _reviewDetail(l10n, review)
          : l10n.agentWorkspaceProductionStageDetailStoryboardSupervisionCombined(
              _reviewDetail(l10n, review),
              ' $scopeLine',
            ),
      domainTool: 'get_flowData',
      domainArgs: storyboardArgs,
      subAgentTool: review.nextAction == 'generate_storyboard'
          ? 'run_sub_agent_storyboard_gen'
          : null,
      subAgentArgs: review.nextAction == 'generate_storyboard'
          ? buildProductionSubAgentArgs(
              storyboardIds: storyboardIds,
              assetIds: review.assetIds,
              assetTypes: review.assetTypes,
            )
          : null,
      prompt: review.nextAction == 'generate_storyboard'
          ? l10n.agentWorkspaceProductionStagePromptStoryboardSupervisionGenerate(
              buildProductionStoryboardGenerationPrompt(
                l10n: l10n,
                storyboardIds: storyboardIds,
                assetIds: review.assetIds,
                summary: review.summary,
                executionHint: executionHint,
              ),
            )
          : null,
    );
  }
  final data = flowSnapshot['storyboard'];
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    if (rows.isEmpty) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowStoryboard,
        flowKey: 'storyboard',
        status: ProductionWorkspaceStageStatus.pendingGenerate,
        detail: l10n.agentWorkspaceProductionStageDetailStoryboardEmpty,
        subAgentTool: 'run_sub_agent_storyboard_gen',
        prompt: l10n.agentWorkspaceProductionStagePromptStoryboardEmpty,
      );
    }
    final targetRows = rows
        .where(productionStoryboardEntryNeedsImageGeneration)
        .toList(growable: false);
    final missingIds = extractProductionStoryboardMissingImageIds(rows);
    final promptAssetIds = extractProductionReferencedAssetIdsForStoryboardIds(
      rows,
      missingIds,
    );
    final missingCount = missingIds.length;
    final skippedCount = rows.length - targetRows.length;
    final readiness = summarizeProductionStoryboardReadiness(l10n, rows);
    if (missingCount > 0) {
      final idsLabel = missingIds.take(6).join(', ');
      final idsTail = missingIds.length > 6
          ? l10n.agentWorkspaceProductionStageDetailStoryboardMissingIdsTail(
              missingIds.length,
            )
          : '';
      final skippedClause = skippedCount > 0
          ? l10n.agentWorkspaceProductionStageDetailStoryboardMissingSkipped(
              skippedCount,
            )
          : '';
      final reviewScope = summarizeProductionStoryboardReviewScope(
        l10n,
        missingIds,
      );
      final reviewClause = reviewScope.isEmpty
          ? ''
          : l10n.agentWorkspaceProductionStageDetailStoryboardMissingReview(
              reviewScope,
            );
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowStoryboard,
        flowKey: 'storyboard',
        status: ProductionWorkspaceStageStatus.needsStoryboardFrames,
        detail: l10n.agentWorkspaceProductionStageDetailStoryboardMissing(
          targetRows.length,
          missingCount,
          idsLabel,
          idsTail,
          skippedClause,
          reviewClause,
          readiness,
        ),
        subAgentTool: 'run_sub_agent_storyboard_gen',
        subAgentArgs: buildProductionSubAgentArgs(
          storyboardIds: missingIds,
          assetIds: promptAssetIds,
        ),
        prompt: l10n.agentWorkspaceProductionStagePromptStoryboardContinue(
          buildProductionStoryboardGenerationPrompt(
            l10n: l10n,
            storyboardIds: missingIds,
            assetIds: promptAssetIds,
            executionHint: executionHint,
          ),
        ),
      );
    }
    final skippedClause = skippedCount > 0
        ? l10n.agentWorkspaceProductionStageDetailStoryboardCompleteSkipped(
            skippedCount,
          )
        : '';
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.storyboardComplete,
      detail: l10n.agentWorkspaceProductionStageDetailStoryboardComplete(
        targetRows.length,
        skippedClause,
        readiness,
      ),
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardReviewArgs(),
    );
  }
  if (!scriptPlanReady &&
      activeKey != 'storyboard' &&
      toolName != 'generate_storyboard' &&
      toolName != 'run_sub_agent_storyboard_gen' &&
      toolName != 'run_sub_agent_storyboard_panel') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.waitingScriptPlan,
      detail: l10n.agentWorkspaceProductionStageDetailStoryboardWaitScript,
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  if (scriptPlanReady &&
      !scriptPlanAdvanceReady &&
      activeKey != 'storyboard' &&
      toolName != 'generate_storyboard' &&
      toolName != 'run_sub_agent_storyboard_gen' &&
      toolName != 'run_sub_agent_storyboard_panel') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.waitingScriptPlanDepth,
      detail: l10n.agentWorkspaceProductionStageDetailStoryboardWaitScriptDepth,
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  if (scriptPlanAdvanceReady &&
      !storyboardTableReady &&
      activeKey != 'storyboard' &&
      toolName != 'generate_storyboard' &&
      toolName != 'run_sub_agent_storyboard_gen' &&
      toolName != 'run_sub_agent_storyboard_panel') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.waitingStoryboardTable,
      detail: l10n.agentWorkspaceProductionStageDetailStoryboardWaitTable,
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(),
    );
  }
  if (scriptPlanAdvanceReady &&
      storyboardTableReady &&
      !storyboardTableAdvanceReady &&
      !scriptPlanStoryboardReady &&
      activeKey != 'storyboard' &&
      toolName != 'generate_storyboard' &&
      toolName != 'run_sub_agent_storyboard_gen' &&
      toolName != 'run_sub_agent_storyboard_panel') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.backfillScriptPlanFromTable,
      detail:
          l10n.agentWorkspaceProductionStageDetailStoryboardBackfillFromTable,
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  if (scriptPlanAdvanceReady &&
      storyboardTableReady &&
      !storyboardTableAdvanceReady &&
      activeKey != 'storyboard' &&
      toolName != 'generate_storyboard' &&
      toolName != 'run_sub_agent_storyboard_gen' &&
      toolName != 'run_sub_agent_storyboard_panel') {
    final cov = _storyboardTableCoverageMeta(flowSnapshot['storyboardTable']);
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.waitingStoryboardTableCoverage,
      detail:
          l10n.agentWorkspaceProductionStageDetailStoryboardWaitTableCoverage,
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(),
      storyboardTableCoverageSampledRows: cov?.sampled,
      storyboardTableCoverageTotalRows: cov?.total,
    );
  }
  if (activeKey == 'storyboard' ||
      toolName == 'generate_storyboard' ||
      toolName == 'run_sub_agent_storyboard_gen' ||
      toolName == 'run_sub_agent_storyboard_panel') {
    final affectedIds =
        toolName == 'generate_storyboard' ||
            toolName == 'run_sub_agent_storyboard_gen'
        ? extractProductionActionCandidateIds(
            selectedTool: 'generate_storyboard',
            toolName: toolName,
            suggestedFlowKey: suggestedFlowKey,
            result: result,
            toolArguments: toolArguments,
          )
        : toolName == 'run_sub_agent_storyboard_panel'
        ? extractProductionStoryboardPromptScopeIds(toolName, toolArguments)
        : const <int>[];
    final refreshArgs =
        toolName == 'generate_storyboard' ||
            toolName == 'run_sub_agent_storyboard_gen' ||
            toolName == 'run_sub_agent_storyboard_panel'
        ? buildProductionStoryboardGenerationArgs(ids: affectedIds)
        : buildProductionStoryboardReviewArgs();
    final narrowStoryboardTools =
        toolName == 'generate_storyboard' ||
        toolName == 'run_sub_agent_storyboard_gen' ||
        toolName == 'run_sub_agent_storyboard_panel';
    final storyboardRefreshHint = !narrowStoryboardTools
        ? ProductionWorkspaceRefreshHint.refreshStoryboardSnapshot
        : affectedIds.isEmpty
        ? ProductionWorkspaceRefreshHint.refreshStoryboardSnapshot
        : ProductionWorkspaceRefreshHint.rereadMissingFrameState;
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.suggestRefresh,
      refreshHint: storyboardRefreshHint,
      detail:
          toolName == 'generate_storyboard' ||
              toolName == 'run_sub_agent_storyboard_gen' ||
              toolName == 'run_sub_agent_storyboard_panel'
          ? affectedIds.isEmpty
                ? l10n.agentWorkspaceProductionStageDetailStoryboardRefreshGenWide
                : l10n.agentWorkspaceProductionStageDetailStoryboardRefreshGenNarrow(
                    affectedIds.join(', '),
                  )
          : l10n.agentWorkspaceProductionStageDetailStoryboardRefreshOther,
      domainTool: 'get_flowData',
      domainArgs: refreshArgs,
    );
  }
  return ProductionWorkspaceStage(
    title: l10n.agentWorkspaceProductionStageFlowStoryboard,
    flowKey: 'storyboard',
    status: ProductionWorkspaceStageStatus.pendingRead,
    detail: l10n.agentWorkspaceProductionStageDetailStoryboardPendingRead,
    domainTool: 'get_flowData',
    domainArgs: buildProductionStoryboardReviewArgs(),
  );
}

({int sampled, int total})? _storyboardTableCoverageMeta(Object? value) {
  if (value is Map<String, dynamic>) {
    final sampled = _readInt(value['rowCount']);
    final total = _readInt(value['totalRows']);
    if (sampled <= 0 && total <= 0) return null;
    final effectiveTotal = total > 0 ? total : sampled;
    return (sampled: sampled, total: effectiveTotal);
  }
  if (value is String) {
    final rc = countProductionStoryboardTableRows(value);
    if (rc <= 0) return null;
    return (sampled: rc, total: rc);
  }
  return null;
}

String _reviewDetail(
  AppLocalizations l10n,
  ProductionSupervisionReview review,
) {
  final summary = review.summary.isEmpty
      ? l10n.agentWorkspaceProductionStageReviewSummaryFallback
      : review.summary;
  final reviewScope = summarizeProductionStoryboardReviewScope(
    l10n,
    review.storyboardIds,
  );
  final assetScope = review.nextAction == 'check_assets'
      ? summarizeProductionAssetReviewScope(l10n, review)
      : '';
  final scopeLine = reviewScope.isEmpty
      ? ''
      : l10n.agentWorkspaceProductionStageReviewStoryboardScope(reviewScope);
  final assetLine = assetScope.isEmpty
      ? ''
      : l10n.agentWorkspaceProductionStageReviewAssetScope(assetScope);
  return l10n.agentWorkspaceProductionStageReviewBody(
    review.grade,
    review.severeCount,
    review.mediumCount,
    review.minorCount,
    summary,
    scopeLine,
    assetLine,
  );
}

int _readInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

bool _productionScriptPlanReady(Object? value) {
  return value is String && value.trim().isNotEmpty;
}

bool _productionScriptPlanAdvanceReady(Object? value) {
  if (value is! String) return false;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final sectionCount = countProductionScriptPlanSections(trimmed);
  if (sectionCount >= 3) return true;
  if (sectionCount == 0 && trimmed.length >= 280) return true;
  return false;
}

bool _productionScriptPlanStoryboardReady(Object? value) {
  if (value is! String) return false;
  final sections = summarizeProductionScriptPlanSections(value, maxSections: 6);
  if (sections.isEmpty) return false;
  return sections.any((section) {
    final normalized = section.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.contains('④') ||
        normalized.contains('分场景') ||
        normalized.contains('画面意图') ||
        normalized.contains('镜头意图') ||
        normalized.contains('情绪');
  });
}

bool _productionStoryboardTableReady(Object? value) {
  if (value is String) {
    return value.trim().isNotEmpty &&
        countProductionStoryboardTableRows(value) > 0;
  }
  if (value is Map<String, dynamic>) {
    final rowCount = _readInt(value['rowCount']);
    final totalRows = _readInt(value['totalRows']);
    return rowCount > 0 || totalRows > 0;
  }
  return false;
}

bool _productionStoryboardTableAdvanceReady(Object? value) {
  if (value is String) {
    return value.trim().isNotEmpty &&
        countProductionStoryboardTableRows(value) >= 3;
  }
  if (value is Map<String, dynamic>) {
    final rowCount = _readInt(value['rowCount']);
    final totalRows = _readInt(value['totalRows']);
    if (totalRows <= 0) {
      return rowCount >= 3;
    }
    if (rowCount >= totalRows) {
      return rowCount >= 3;
    }
    final remaining = totalRows - rowCount;
    return rowCount >= 12 && remaining <= 4;
  }
  return false;
}
