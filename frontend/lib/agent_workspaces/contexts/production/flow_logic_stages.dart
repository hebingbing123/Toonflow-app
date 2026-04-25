part of 'flow_logic.dart';

List<ProductionWorkspaceStage> buildProductionWorkspaceStages({
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
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
      review: review,
    ),
    _buildAssetsStage(
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
      result: result,
      review: review,
      toolArguments: toolArguments,
    ),
    _buildStoryboardTableStage(
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
      review: review,
      toolArguments: toolArguments,
    ),
    _buildStoryboardStage(
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
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
  required ProductionSupervisionReview? review,
}) {
  if (review != null && review.target == 'scriptPlan') {
    final planningScriptArgs = buildProductionPlanningScriptArgs();
    return ProductionWorkspaceStage(
      title: '导演计划',
      flowKey: 'scriptPlan',
      statusLabel: _reviewStatusLabel(review),
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
      return const ProductionWorkspaceStage(
        title: '导演计划',
        flowKey: 'scriptPlan',
        statusLabel: '待生成',
        detail: 'scriptPlan 仍为空，先产出导演计划再推进资产与分镜。',
        subAgentTool: 'run_sub_agent_director_plan',
        prompt: '请基于当前 production 上下文生成一版导演计划，并给出执行优先级。',
      );
    }
    final sectionCount = countProductionScriptPlanSections(trimmed);
    final sectionLine = sectionCount > 0 ? '已覆盖 $sectionCount/6 个规划维度，' : '';
    final scriptWindow = summarizeProductionPlanningScriptWindow();
    return ProductionWorkspaceStage(
      title: '导演计划',
      flowKey: 'scriptPlan',
      statusLabel: '待审核',
      detail:
          '已读取 scriptPlan，$sectionLine当前约 ${trimmed.length} 字；复核时先只回看$scriptWindow，再做导演规划审核并推进 assets 与 storyboard。',
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: '请审核当前导演规划，重点检查剧情覆盖、资产匹配与节奏合理性。',
    );
  }
  if (activeKey == 'scriptPlan' || toolName == 'run_sub_agent_director_plan') {
    return ProductionWorkspaceStage(
      title: '导演计划',
      flowKey: 'scriptPlan',
      statusLabel: '建议刷新',
      detail: '导演计划刚变更或正在处理，建议重新读取 scriptPlan 确认最新内容。',
      domainTool: 'get_flowData',
      domainArgs: _scriptPlanCompactArgs(),
    );
  }
  return ProductionWorkspaceStage(
    title: '导演计划',
    flowKey: 'scriptPlan',
    statusLabel: '待读取',
    detail: '先读取 scriptPlan，确认制作优先级与执行顺序。',
    domainTool: 'get_flowData',
    domainArgs: _scriptPlanCompactArgs(),
  );
}

ProductionWorkspaceStage _buildAssetsStage({
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
      title: '资产准备',
      flowKey: 'assets',
      statusLabel: _reviewStatusLabel(review),
      detail:
          '${_reviewDetail(review)} 优先只核对$assetScope，确认后回到 scriptPlan 收束导演计划。',
      domainTool: 'get_flowData',
      domainArgs: assetArgs,
    );
  }
  final data = flowSnapshot['assets'];
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    if (rows.isEmpty) {
      return const ProductionWorkspaceStage(
        title: '资产准备',
        flowKey: 'assets',
        statusLabel: '待规划',
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
    if (missingCount > 0) {
      return ProductionWorkspaceStage(
        title: '资产准备',
        flowKey: 'assets',
        statusLabel: '需补图',
        detail: pendingScope.isEmpty
            ? '共 ${rows.length} 项资产，仍有 $missingCount 项缺少图像结果，适合继续运行素材生成。'
            : '共 ${rows.length} 项资产，$pendingScope 仍缺图，优先只补这批衍生资产更省 token。',
        subAgentTool: 'run_sub_agent_generate_assets',
        subAgentArgs: buildProductionSubAgentArgs(assetIds: pendingDeriveIds),
        prompt: buildProductionAssetGenerationPrompt(
          assetIds: pendingDeriveIds,
        ),
      );
    }
    return ProductionWorkspaceStage(
      title: '资产准备',
      flowKey: 'assets',
      statusLabel: '已齐备',
      detail: '共 ${rows.length} 项资产，图像结果已齐，可继续检查 storyboard 与导演计划。',
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
      title: '资产准备',
      flowKey: 'assets',
      statusLabel: '已定位',
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
      title: '资产准备',
      flowKey: 'assets',
      statusLabel: '已定位',
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
  if (flowSnapshot['scriptPlan'] is String) {
    return ProductionWorkspaceStage(
      title: '资产准备',
      flowKey: 'assets',
      statusLabel: '已收紧',
      detail:
          '已从 scriptPlan 收紧到$scriptPlanAssetScope，优先核对这批素材更省 token；信息不足时再扩读。',
      domainTool: 'get_flowData',
      domainArgs: scriptPlanAssetArgs,
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
    return ProductionWorkspaceStage(
      title: '资产准备',
      flowKey: 'assets',
      statusLabel: '建议刷新',
      detail:
          (toolName == 'generate_deriveAsset' ||
                  toolName == 'run_sub_agent_generate_assets') &&
              refreshArgs.containsKey('ids')
          ? '资产生成动作刚执行，建议先只回读本次受影响资产，确认结果后再决定是否扩读。'
          : '资产相关动作刚执行，建议重新读取 assets 确认最新结果。',
      domainTool: 'get_flowData',
      domainArgs: refreshArgs,
    );
  }
  return ProductionWorkspaceStage(
    title: '资产准备',
    flowKey: 'assets',
    statusLabel: '待读取',
    detail: '读取 assets flow 后可判断是否需要继续做衍生资产或素材生成。',
    domainTool: 'get_flowData',
    domainArgs: _assetsCompactArgs(),
  );
}

ProductionWorkspaceStage _buildStoryboardTableStage({
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
  required ProductionSupervisionReview? review,
  required Map<String, dynamic>? toolArguments,
}) {
  if (review != null && review.target == 'storyboardTable') {
    return ProductionWorkspaceStage(
      title: '分镜表',
      flowKey: 'storyboardTable',
      statusLabel: _reviewStatusLabel(review),
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
  if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) {
      return const ProductionWorkspaceStage(
        title: '分镜表',
        flowKey: 'storyboardTable',
        statusLabel: '待生成',
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
      title: '分镜表',
      flowKey: 'storyboardTable',
      statusLabel: '待审核',
      detail:
          'storyboardTable 已有内容，${digest.isEmpty ? '' : '$digest，'}约 ${trimmed.length} 字，建议先做分镜表审核再推进 storyboard 画面结果。',
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: '请审核当前分镜表，重点检查覆盖度、资产关联与拆分粒度。',
    );
  }
  if (data is Map<String, dynamic>) {
    final rowCount = _readInt(data['rowCount']);
    final totalRows = _readInt(data['totalRows']);
    return ProductionWorkspaceStage(
      title: '分镜表',
      flowKey: 'storyboardTable',
      statusLabel: '已抽样',
      detail: '已窗口读取 $rowCount/$totalRows 行关键列，适合继续审核或修订 storyboardTable。',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(),
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: '请审核当前分镜表，重点检查覆盖度、资产关联与拆分粒度。',
    );
  }
  if (activeKey == 'storyboardTable' ||
      toolName == 'run_sub_agent_storyboard_table') {
    final affectedIds = toolName == 'run_sub_agent_storyboard_table'
        ? extractProductionStoryboardPromptScopeIds(toolName, toolArguments)
        : const <int>[];
    return ProductionWorkspaceStage(
      title: '分镜表',
      flowKey: 'storyboardTable',
      statusLabel: '建议刷新',
      detail: affectedIds.isEmpty
          ? '分镜表刚变更或正在处理，建议重新读取 storyboardTable。'
          : '分镜表刚变更，建议先只回读镜头 #${affectedIds.join(', ')} 对应的 storyboardTable 行。',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(ids: affectedIds),
    );
  }
  return ProductionWorkspaceStage(
    title: '分镜表',
    flowKey: 'storyboardTable',
    statusLabel: '待读取',
    detail: '需要时可读取 storyboardTable 审阅结构化镜头表。',
    domainTool: 'get_flowData',
    domainArgs: buildProductionStoryboardTableReadArgs(),
  );
}

ProductionWorkspaceStage _buildStoryboardStage({
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
  required ProductionSupervisionReview? review,
  required String? suggestedFlowKey,
  required Object? result,
  required Map<String, dynamic>? toolArguments,
}) {
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
      title: '分镜画面',
      flowKey: 'storyboard',
      statusLabel: review.nextAction == 'generate_storyboard' ? '待补帧' : '待核对',
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
            )
          : null,
      prompt: review.nextAction == 'generate_storyboard'
          ? '请根据最近审核意见继续推进 storyboard。${buildProductionStoryboardGenerationPrompt(storyboardIds: storyboardIds, assetIds: review.assetIds, summary: review.summary)}'
          : null,
    );
  }
  final data = flowSnapshot['storyboard'];
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    if (rows.isEmpty) {
      return const ProductionWorkspaceStage(
        title: '分镜画面',
        flowKey: 'storyboard',
        statusLabel: '待生成',
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
    if (missingCount > 0) {
      final idsLabel = missingIds.take(6).join(', ');
      final idTail = missingIds.length > 6 ? ' 等 ${missingIds.length} 个镜头' : '';
      final reviewScope = summarizeProductionStoryboardReviewScope(missingIds);
      return ProductionWorkspaceStage(
        title: '分镜画面',
        flowKey: 'storyboard',
        statusLabel: '需补帧',
        detail:
            '需出图 ${targetRows.length} 个镜头，仍有 $missingCount 个缺少画面结果（#$idsLabel$idTail）${skippedCount > 0 ? '；另有 $skippedCount 个镜头为纯文本模式，无需出图。' : '。'}${reviewScope.isEmpty ? '' : ' $reviewScope。'}',
        subAgentTool: 'run_sub_agent_storyboard_gen',
        subAgentArgs: buildProductionSubAgentArgs(
          storyboardIds: missingIds,
          assetIds: promptAssetIds,
        ),
        prompt:
            '请继续推进 storyboard。${buildProductionStoryboardGenerationPrompt(storyboardIds: missingIds, assetIds: promptAssetIds)}',
      );
    }
    return ProductionWorkspaceStage(
      title: '分镜画面',
      flowKey: 'storyboard',
      statusLabel: '已完成',
      detail:
          '需出图 ${targetRows.length} 个镜头，画面结果齐备${skippedCount > 0 ? '；另有 $skippedCount 个纯文本镜头按设计无需出图' : ''}，可准备写回或继续导演计划。',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardReviewArgs(),
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
    return ProductionWorkspaceStage(
      title: '分镜画面',
      flowKey: 'storyboard',
      statusLabel: '建议刷新',
      detail:
          toolName == 'generate_storyboard' ||
              toolName == 'run_sub_agent_storyboard_gen' ||
              toolName == 'run_sub_agent_storyboard_panel'
          ? affectedIds.isEmpty
                ? '分镜动作刚执行，建议先按补图最小字段读取 storyboard，再决定是否继续补帧或写回。'
                : '分镜动作刚执行，建议先只回读本次镜头 #${affectedIds.join(', ')} 的补图状态。'
          : '分镜动作刚执行，建议重新读取 storyboard 再决定是否写回。',
      domainTool: 'get_flowData',
      domainArgs: refreshArgs,
    );
  }
  return ProductionWorkspaceStage(
    title: '分镜画面',
    flowKey: 'storyboard',
    statusLabel: '待读取',
    detail: '读取 storyboard 后可判断是否需要继续补图或直接写回结果。',
    domainTool: 'get_flowData',
    domainArgs: buildProductionStoryboardReviewArgs(),
  );
}

String _reviewStatusLabel(ProductionSupervisionReview review) {
  if (review.severeCount > 0 || review.grade == 'D') return '需返工';
  if (review.grade == 'C') return '待修订';
  if (review.grade == 'B') return '可推进';
  return '已通过';
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
