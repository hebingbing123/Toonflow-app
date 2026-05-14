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
      detail: _reviewDetail(review),
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
          ? '请根据最近审核意见修订 scriptPlan，优先解决：${review.summary}'
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
        detail: 'scriptPlan 仍为空，先产出导演计划再推进资产与分镜。',
        subAgentTool: 'run_sub_agent_director_plan',
        prompt: '请基于当前 production 上下文生成一版导演计划，并给出执行优先级。',
      );
    }
    final sectionCount = countProductionScriptPlanSections(trimmed);
    final sectionLine = sectionCount > 0 ? '已覆盖 $sectionCount/6 个规划维度，' : '';
    final scriptWindow = summarizeProductionPlanningScriptWindow();
    if (!_productionScriptPlanAdvanceReady(trimmed)) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
        flowKey: 'scriptPlan',
        status: ProductionWorkspaceStageStatus.pendingRefineScriptPlan,
        detail:
            '已读取 scriptPlan，$sectionLine当前约 ${trimmed.length} 字；下游暂不放行，建议先补到至少 3 个规划维度，再进入审核与 assets/storyboard 主链。',
        subAgentTool: 'run_sub_agent_director_plan',
        prompt: '请继续完善当前 scriptPlan，至少补齐 3 个规划维度，并明确情绪推进、资产依赖与镜头意图。',
      );
    }
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
      flowKey: 'scriptPlan',
      status: ProductionWorkspaceStageStatus.pendingReview,
      detail:
          '已读取 scriptPlan，$sectionLine当前约 ${trimmed.length} 字；复核时先只回看$scriptWindow，再做导演规划审核并推进 assets 与 storyboard。',
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: '请审核当前导演规划，重点检查剧情覆盖、资产匹配与节奏合理性。',
    );
  }
  if (activeKey == 'scriptPlan' || toolName == 'run_sub_agent_director_plan') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
      flowKey: 'scriptPlan',
      status: ProductionWorkspaceStageStatus.suggestRefresh,
      detail: '导演计划刚变更或正在处理，建议先刷新导演计划，确认最新内容后再推进下游阶段。',
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  return ProductionWorkspaceStage(
    title: l10n.agentWorkspaceProductionStageFlowScriptPlan,
    flowKey: 'scriptPlan',
    status: ProductionWorkspaceStageStatus.pendingRead,
    detail: '先读取 scriptPlan，确认制作优先级与执行顺序。',
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
    final assetScope = summarizeProductionAssetScope(assetArgs);
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.fromSupervisionReview(review),
      detail:
          '${_reviewDetail(review)} 优先只核对$assetScope，确认后回到 scriptPlan 收束导演计划。',
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
    flowSnapshot['scriptPlan'],
  );
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    if (rows.isEmpty) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowAssets,
        flowKey: 'assets',
        status: ProductionWorkspaceStageStatus.pendingAssetPlan,
        detail: 'assets 为空，先规划衍生素材并补齐最小可行资产集。',
        subAgentTool: 'run_sub_agent_derive_assets',
        prompt: '请基于当前空白 assets flow 规划最小可行的衍生素材集合，并说明优先级。',
      );
    }
    final readyCount = rows.where((row) {
      return productionFlowEntryHasMediaResult(row);
    }).length;
    final missingCount = rows.length - readyCount;
    final pendingDeriveIds = extractProductionPendingDeriveAssetIds(rows);
    final pendingScope = summarizeProductionAssetFocusIds(pendingDeriveIds);
    final readiness = summarizeProductionAssetReadiness(rows);
    if (missingCount > 0) {
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowAssets,
        flowKey: 'assets',
        status: ProductionWorkspaceStageStatus.needsAssetImages,
        detail: pendingScope.isEmpty
            ? '共 ${rows.length} 项资产，仍有 $missingCount 项缺少图像结果，适合继续运行素材生成。$readiness。'
            : '共 ${rows.length} 项资产，$pendingScope 仍缺图，优先只补这批衍生资产更省 token。$readiness。',
        subAgentTool: 'run_sub_agent_generate_assets',
        subAgentArgs: buildProductionSubAgentArgs(assetIds: pendingDeriveIds),
        prompt: buildProductionAssetGenerationPrompt(
          assetIds: pendingDeriveIds,
          executionHint: executionHint,
        ),
      );
    }
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.assetsReady,
      detail: '共 ${rows.length} 项资产，图像结果已齐，可继续检查 storyboard 与导演计划。$readiness。',
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
      detail: '当前分镜表窗口引用了 ${ids.length} 项资产，优先核对这批素材更省 token。',
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
      detail: '当前分镜窗口引用了 ${ids.length} 项资产，优先核对这批素材更省 token。',
      domainTool: 'get_flowData',
      domainArgs: storyboardAssetArgs,
    );
  }
  final scriptPlanAssetArgs = buildProductionScriptPlanAssetArgs(
    flowSnapshot['scriptPlan'],
  );
  final scriptPlanAssetScope = summarizeProductionAssetScope(
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
      detail: '当前 scriptPlan 已有内容但还不够完整，先补齐导演计划的关键维度，再规划 assets，避免素材准备跑偏。',
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  if (flowSnapshot['scriptPlan'] is String) {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowAssets,
      flowKey: 'assets',
      status: ProductionWorkspaceStageStatus.assetsNarrowedFromScriptPlan,
      detail:
          '已从 scriptPlan 收紧到$scriptPlanAssetScope，优先核对这批素材更省 token；信息不足时再扩读。',
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
      detail: '先读取或生成 scriptPlan，再规划 assets，避免素材补齐脱离导演节奏与改写约束。',
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
          ? '资产生成动作刚执行，建议先回读本次受影响资产，确认结果后再决定是否扩读。'
          : '资产相关动作刚执行，建议先刷新资产结果，确认最新状态后再决定是否继续补素材。',
      domainTool: 'get_flowData',
      domainArgs: refreshArgs,
    );
  }
  return ProductionWorkspaceStage(
    title: l10n.agentWorkspaceProductionStageFlowAssets,
    flowKey: 'assets',
    status: ProductionWorkspaceStageStatus.pendingRead,
    detail: '读取 assets flow 后可判断是否需要继续做衍生资产或素材生成。',
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
      detail: _reviewDetail(review),
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
          '请根据最近审核意见修订 storyboardTable。${buildProductionStoryboardTableRevisionPrompt(review)}',
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
        detail: 'storyboardTable 为空，适合先补结构化镜头表。',
        subAgentTool: 'run_sub_agent_storyboard_table',
        prompt: '请先产出结构化 storyboardTable，并保持字段清晰可回写。',
      );
    }
    final rowCount = countProductionStoryboardTableRows(trimmed);
    final assetCount = extractProductionReferencedAssetIds(trimmed).length;
    final digest = <String>[
      if (rowCount > 0) '共 $rowCount 行',
      if (assetCount > 0) '关联 $assetCount 项资产',
    ].join('，');
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: ProductionWorkspaceStageStatus.pendingReview,
      detail:
          'storyboardTable 已有内容，${digest.isEmpty ? '' : '$digest，'}约 ${trimmed.length} 字，建议先做分镜表审核再推进 storyboard 画面结果。${summarizeProductionStoryboardTableCoverage(sampledRows: rowCount, totalRows: rowCount)}。',
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: '请审核当前分镜表，重点检查覆盖度、资产关联与拆分粒度。',
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
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: tableStatus,
      detail: advanceReady
          ? '已窗口读取 $rowCount/$totalRows 行关键列，适合继续审核或修订 storyboardTable。${summarizeProductionStoryboardTableCoverage(sampledRows: rowCount, totalRows: totalRows)}。'
          : scriptPlanReady && !scriptPlanStoryboardReady
          ? '已窗口读取 $rowCount/$totalRows 行关键列，但当前 scriptPlan 还缺少足够明确的分场景情绪或画面意图，先回补导演计划，再继续扩读 storyboardTable。${summarizeProductionStoryboardTableCoverage(sampledRows: rowCount, totalRows: totalRows)}。'
          : '已窗口读取 $rowCount/$totalRows 行关键列，但覆盖还不够，先扩读或补齐关键镜头表，再推进 storyboard。${summarizeProductionStoryboardTableCoverage(sampledRows: rowCount, totalRows: totalRows)}。',
      domainTool: 'get_flowData',
      domainArgs: scriptPlanReady && !scriptPlanStoryboardReady
          ? _scriptPlanCompactArgs()
          : buildProductionStoryboardTableReadArgs(),
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: '请审核当前分镜表，重点检查覆盖度、资产关联与拆分粒度。',
    );
  }
  if (!scriptPlanReady &&
      activeKey != 'storyboardTable' &&
      toolName != 'run_sub_agent_storyboard_table') {
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
      flowKey: 'storyboardTable',
      status: ProductionWorkspaceStageStatus.waitingScriptPlan,
      detail: '先读取或生成 scriptPlan，再拆分 storyboardTable，避免镜头表脱离导演计划。',
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
      detail: '当前 scriptPlan 已有内容但还不够完整，先补齐导演计划的关键维度，再拆分 storyboardTable。',
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
          ? '分镜表刚变更或正在处理，建议先刷新分镜表，再判断是否继续审核或修订。'
          : '分镜表刚变更，建议先回读镜头 #${affectedIds.join(', ')} 对应的局部分镜表行。',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(ids: affectedIds),
    );
  }
  return ProductionWorkspaceStage(
    title: l10n.agentWorkspaceProductionStageFlowStoryboardTable,
    flowKey: 'storyboardTable',
    status: ProductionWorkspaceStageStatus.pendingRead,
    detail: '需要时可读取 storyboardTable 审阅结构化镜头表。',
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
    flowSnapshot['scriptPlan'],
  );
  if (review != null &&
      (review.nextAction == 'check_storyboard' ||
          review.nextAction == 'generate_storyboard')) {
    final storyboardArgs = review.nextAction == 'generate_storyboard'
        ? buildProductionReviewStoryboardGenerationArgs(review)
        : buildProductionReviewStoryboardArgs(review);
    final storyboardIds = review.storyboardIds;
    final reviewScope = summarizeProductionStoryboardReviewScope(storyboardIds);
    final scopeLine = storyboardIds.isEmpty
        ? review.nextAction == 'generate_storyboard'
              ? '建议先读取缺帧镜头状态，再最小化补图。'
              : '建议先读取紧凑 storyboard 状态，确认审核涉及的镜头。'
        : '审核已定位 ${storyboardIds.length} 个镜头，优先只看这批 storyboard 更省 token。${reviewScope.isEmpty ? '' : ' $reviewScope。'}';
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: review.nextAction == 'generate_storyboard'
          ? ProductionWorkspaceStageStatus.storyboardFramesPending
          : ProductionWorkspaceStageStatus.storyboardPendingVerify,
      detail: '${_reviewDetail(review)} $scopeLine',
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
          ? '请根据最近审核意见继续推进 storyboard。${buildProductionStoryboardGenerationPrompt(storyboardIds: storyboardIds, assetIds: review.assetIds, summary: review.summary, executionHint: executionHint)}'
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
        detail: 'storyboard 为空，先生成第一版分镜画面。',
        subAgentTool: 'run_sub_agent_storyboard_gen',
        prompt: '请基于当前 production 上下文生成第一版 storyboard，并保持最小可行镜头集。',
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
    final readiness = summarizeProductionStoryboardReadiness(rows);
    if (missingCount > 0) {
      final idsLabel = missingIds.take(6).join(', ');
      final idTail = missingIds.length > 6 ? ' 等 ${missingIds.length} 个镜头' : '';
      final reviewScope = summarizeProductionStoryboardReviewScope(missingIds);
      return ProductionWorkspaceStage(
        title: l10n.agentWorkspaceProductionStageFlowStoryboard,
        flowKey: 'storyboard',
        status: ProductionWorkspaceStageStatus.needsStoryboardFrames,
        detail:
            '需出图 ${targetRows.length} 个镜头，仍有 $missingCount 个缺少画面结果（#$idsLabel$idTail）${skippedCount > 0 ? '；另有 $skippedCount 个镜头为纯文本模式，无需出图。' : '。'}${reviewScope.isEmpty ? '' : ' $reviewScope。'} $readiness。',
        subAgentTool: 'run_sub_agent_storyboard_gen',
        subAgentArgs: buildProductionSubAgentArgs(
          storyboardIds: missingIds,
          assetIds: promptAssetIds,
        ),
        prompt:
            '请继续推进 storyboard。${buildProductionStoryboardGenerationPrompt(storyboardIds: missingIds, assetIds: promptAssetIds, executionHint: executionHint)}',
      );
    }
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.storyboardComplete,
      detail:
          '需出图 ${targetRows.length} 个镜头，画面结果齐备${skippedCount > 0 ? '；另有 $skippedCount 个纯文本镜头按设计无需出图' : ''}，可准备写回或继续导演计划。$readiness。',
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
      detail: '先读取或生成 scriptPlan，再推进 storyboard，避免直接补图但情绪和镜头意图未定。',
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
      detail:
          '当前 scriptPlan 已有内容但还不够完整，先补齐导演计划的关键维度，再推进 storyboard，避免补图时情绪和镜头意图仍发散。',
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
      detail: '先补 storyboardTable 再推进 storyboard，避免直接出图时镜头拆分和资产关联还没定型。',
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
          'storyboardTable 已有基础内容，但当前 scriptPlan 对分场景情绪或画面意图交代还不够，先细化导演计划，再继续扩读分镜表并推进 storyboard。',
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
    return ProductionWorkspaceStage(
      title: l10n.agentWorkspaceProductionStageFlowStoryboard,
      flowKey: 'storyboard',
      status: ProductionWorkspaceStageStatus.waitingStoryboardTableCoverage,
      detail:
          'storyboardTable 已有基础内容，但覆盖还不够，先扩读或补齐关键镜头表，再推进 storyboard，避免在镜头拆分未定型时直接出图。',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(),
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
                ? '分镜动作刚执行，建议先刷新分镜结果，再决定是否继续补帧或写回。'
                : '分镜动作刚执行，建议先回读本次镜头 #${affectedIds.join(', ')} 的缺帧状态。'
          : '分镜动作刚执行，建议先刷新分镜结果，再决定是否写回。',
      domainTool: 'get_flowData',
      domainArgs: refreshArgs,
    );
  }
  return ProductionWorkspaceStage(
    title: l10n.agentWorkspaceProductionStageFlowStoryboard,
    flowKey: 'storyboard',
    status: ProductionWorkspaceStageStatus.pendingRead,
    detail: '读取 storyboard 后可判断是否需要继续补图或直接写回结果。',
    domainTool: 'get_flowData',
    domainArgs: buildProductionStoryboardReviewArgs(),
  );
}

String _reviewDetail(ProductionSupervisionReview review) {
  final summary = review.summary.isEmpty ? '请按审核结果推进下一步。' : review.summary;
  final reviewScope = summarizeProductionStoryboardReviewScope(
    review.storyboardIds,
  );
  final assetScope = review.nextAction == 'check_assets'
      ? summarizeProductionAssetReviewScope(review)
      : '';
  final scopeLine = reviewScope.isEmpty ? '' : ' 局部范围：$reviewScope。';
  final assetLine = assetScope.isEmpty ? '' : ' 资产范围：$assetScope。';
  return '审核等级 ${review.grade}，严重 ${review.severeCount} / 中等 ${review.mediumCount} / 轻微 ${review.minorCount}。$summary$scopeLine$assetLine';
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
