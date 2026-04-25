part of 'flow_logic.dart';

List<ProductionWorkspaceRecipe> buildProductionWorkspaceRecipes({
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
}) {
  final normalizedTool = toolName?.trim() ?? '';
  if (normalizedTool.isEmpty || result is! Map<String, dynamic>) {
    return const <ProductionWorkspaceRecipe>[];
  }
  final review = parseProductionSupervisionReview(result);
  if (normalizedTool == 'run_sub_agent_production_supervision' &&
      review != null) {
    return _buildSupervisionRecipes(review);
  }
  final normalizedKey = suggestedFlowKey?.trim() ?? '';

  if (normalizedTool == 'get_flowData') {
    final data = result['data'];
    switch (normalizedKey) {
      case 'assets':
        return _buildAssetRecipes(data);
      case 'storyboard':
        return _buildStoryboardRecipes(data);
      case 'scriptPlan':
        return _buildScriptPlanRecipes(data);
      case 'storyboardTable':
        return _buildStoryboardTableRecipes(data);
      default:
        return const <ProductionWorkspaceRecipe>[];
    }
  }

  if (normalizedTool == 'generate_storyboard') {
    final affectedIds = extractProductionActionCandidateIds(
      selectedTool: 'generate_storyboard',
      toolName: toolName,
      suggestedFlowKey: suggestedFlowKey,
      result: result,
    );
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '刷新分镜 flow',
        detail: affectedIds.isEmpty
            ? '分镜生成动作已执行，先按补图最小字段回读 storyboard 再决定是否写回。'
            : '分镜生成动作已执行，先只回读本次镜头 #${affectedIds.join(', ')} 的补图状态。',
        flowKey: 'storyboard',
        domainTool: 'get_flowData',
        domainArgs: buildProductionStoryboardGenerationArgs(ids: affectedIds),
      ),
      ProductionWorkspaceRecipe(
        title: '继续导演计划',
        detail: '如分镜结果还不稳定，回到 scriptPlan 生成下一轮导演决策。',
        flowKey: 'scriptPlan',
        domainTool: 'get_flowData',
        subAgentTool: 'run_sub_agent_director_plan',
      ),
    ];
  }

  if (normalizedTool == 'generate_deriveAsset' ||
      normalizedTool == 'add_deriveAsset' ||
      normalizedTool == 'del_deriveAsset') {
    final affectedIds = normalizedTool == 'generate_deriveAsset'
        ? extractProductionActionCandidateIds(
            selectedTool: 'generate_deriveAsset',
            toolName: toolName,
            suggestedFlowKey: suggestedFlowKey,
            result: result,
          )
        : const <int>[];
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '刷新资产 flow',
        detail: affectedIds.isEmpty
            ? '资产动作已执行，先拉取最新 assets 结果再决定是否写回。'
            : '资产生成动作已执行，先只回读本次资产 #${affectedIds.join(', ')} 的最新状态。',
        flowKey: 'assets',
        domainTool: 'get_flowData',
        domainArgs: buildProductionAssetReadArgs(ids: affectedIds),
      ),
      ProductionWorkspaceRecipe(
        title: '继续资产子代理',
        detail: '若仍缺素材，可直接衔接资产子代理推进下一轮生成。',
        flowKey: 'assets',
        subAgentTool: 'run_sub_agent_generate_assets',
        prompt: affectedIds.isEmpty
            ? '请基于最新 assets flow 判断缺失素材，并执行下一轮最小可行生成动作。'
            : '请先核对刚生成的资产 ids=${affectedIds.join(',')} 是否已达标，再只补剩余缺口，避免重跑无关素材。',
      ),
    ];
  }

  return const <ProductionWorkspaceRecipe>[];
}

List<ProductionWorkspaceRecipe> _buildAssetRecipes(Object? data) {
  if (data is List && data.isEmpty) {
    return const <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '先生成资产计划',
        detail: '当前 assets 为空，优先让子代理补齐衍生素材规划。',
        flowKey: 'assets',
        subAgentTool: 'run_sub_agent_derive_assets',
        prompt: '请基于当前空白 assets flow 规划最小可行的衍生素材集合，并说明优先级。',
      ),
    ];
  }
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    final withoutUrl = rows.where((row) {
      return !productionFlowEntryHasMediaResult(row);
    }).length;
    if (withoutUrl > 0) {
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '继续资产生成',
          detail: '仍有素材缺少图像结果，适合直接运行素材生成子代理。',
          flowKey: 'assets',
          subAgentTool: 'run_sub_agent_generate_assets',
          prompt: '请基于当前 assets flow 优先补齐缺少图像结果的素材，并执行最小可行生成动作。',
        ),
        ProductionWorkspaceRecipe(
          title: '刷新分镜需求',
          detail: '素材缺口补齐后通常需要回看 storyboard 是否还能沿用当前方案。',
          flowKey: 'storyboard',
          domainTool: 'get_flowData',
          domainArgs: buildProductionStoryboardReviewArgs(),
        ),
      ];
    }
  }
  return <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: '检查分镜 flow',
      detail: '资产已具备基础结果，可切到 storyboard 评估镜头生成状态。',
      flowKey: 'storyboard',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardReviewArgs(),
    ),
    ProductionWorkspaceRecipe(
      title: '整理导演计划',
      detail: '若素材已基本齐全，可生成下一轮导演计划收束 production 节奏。',
      flowKey: 'scriptPlan',
      subAgentTool: 'run_sub_agent_director_plan',
      prompt: '请结合现有素材状态与 scriptPlan，输出下一轮导演计划与执行优先级。',
    ),
  ];
}

List<ProductionWorkspaceRecipe> _buildStoryboardRecipes(Object? data) {
  if (data is List && data.isEmpty) {
    return const <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '生成第一版分镜',
        detail: '当前 storyboard 为空，优先运行分镜生成子代理建立初版镜头。',
        flowKey: 'storyboard',
        subAgentTool: 'run_sub_agent_storyboard_gen',
        prompt: '请基于当前 production 上下文生成第一版 storyboard，并保持最小可行镜头集。',
      ),
    ];
  }
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    final missingIds = extractProductionStoryboardMissingImageIds(rows);
    final assetArgs = buildProductionFlowAssetArgs(rows);
    if (missingIds.isNotEmpty) {
      final idsLabel = missingIds.take(6).join(', ');
      final idTail = missingIds.length > 6 ? ' 等 ${missingIds.length} 个镜头' : '';
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '继续补齐分镜图',
          detail: '优先只补缺帧镜头 #$idsLabel$idTail，避免把已完成镜头整批重跑。',
          flowKey: 'storyboard',
          subAgentTool: 'run_sub_agent_storyboard_gen',
          prompt:
              '请继续推进 storyboard。${buildProductionStoryboardGenerationPrompt(storyboardIds: missingIds)}',
        ),
        ProductionWorkspaceRecipe(
          title: '核对关联资产',
          detail: assetArgs.containsKey('ids')
              ? '优先只看当前分镜窗口实际引用的资产，避免把无关素材带入分镜补图。'
              : '当前分镜摘要尚未定位出明确资产 ID，退回紧凑 assets 摘要读取。',
          flowKey: 'assets',
          domainTool: 'get_flowData',
          domainArgs: assetArgs,
        ),
        ProductionWorkspaceRecipe(
          title: '检查分镜表',
          detail: '必要时切到 storyboardTable 审阅结构化镜头表后再回写。',
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
          domainArgs: buildProductionStoryboardTableReadArgs(ids: missingIds),
        ),
      ];
    }
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '核对关联资产',
        detail: assetArgs.containsKey('ids')
            ? '分镜已引用明确资产，可先核对这批资产是否足够支撑后续导演调整。'
            : '当前分镜摘要未定位出明确资产 ID，先读紧凑 assets 摘要即可。',
        flowKey: 'assets',
        domainTool: 'get_flowData',
        domainArgs: assetArgs,
      ),
      ProductionWorkspaceRecipe(
        title: '刷新导演计划',
        detail: '分镜已有基础结果，适合回到 scriptPlan 整理下一轮导演决策。',
        flowKey: 'scriptPlan',
        domainTool: 'get_flowData',
        subAgentTool: 'run_sub_agent_director_plan',
      ),
    ];
  }
  return const <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: '刷新导演计划',
      detail: '分镜已有基础结果，适合回到 scriptPlan 整理下一轮导演决策。',
      flowKey: 'scriptPlan',
      domainTool: 'get_flowData',
      subAgentTool: 'run_sub_agent_director_plan',
    ),
  ];
}

List<ProductionWorkspaceRecipe> _buildScriptPlanRecipes(Object? data) {
  if (data is String && data.trim().isEmpty) {
    return const <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '先生成导演计划',
        detail: '当前 scriptPlan 为空，优先建立导演计划再推进资产或分镜。',
        flowKey: 'scriptPlan',
        subAgentTool: 'run_sub_agent_director_plan',
        prompt: '请基于当前 production 上下文生成一版导演计划，并给出执行优先级。',
      ),
    ];
  }
  final assetArgs = buildProductionScriptPlanAssetArgs(data);
  final assetScope = summarizeProductionAssetScope(assetArgs);
  final scriptWindow = summarizeProductionPlanningScriptWindow();
  return <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: '审核导演计划',
      detail: '导演计划已有内容，先做一次监督审核更容易在低成本阶段发现节奏和资产问题。',
      flowKey: 'scriptPlan',
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: '请审核当前导演规划，重点检查剧情覆盖、资产匹配与节奏合理性。',
    ),
    ProductionWorkspaceRecipe(
      title: '回看剧本依据',
      detail: '先只回看$scriptWindow，确认导演计划与原文节奏一致，再决定是否扩读。',
      flowKey: 'script',
      domainTool: 'get_flowData',
      domainArgs: buildProductionPlanningScriptArgs(),
    ),
    ProductionWorkspaceRecipe(
      title: '检查关键资产',
      detail: assetArgs.containsKey('ids')
          ? '导演计划已点名$assetScope，先精确核对再决定是否扩读其他素材。'
          : '导演计划已有内容，先核对$assetScope是否支撑执行，信息不足时再补更多资产。',
      flowKey: 'assets',
      domainTool: 'get_flowData',
      domainArgs: assetArgs,
    ),
    ProductionWorkspaceRecipe(
      title: '先看分镜表落地',
      detail: '如计划已定，先抽样检查 storyboardTable 结构更省 token，再决定是否读取 storyboard 画面结果。',
      flowKey: 'storyboardTable',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(),
    ),
  ];
}

List<ProductionWorkspaceRecipe> _buildStoryboardTableRecipes(Object? data) {
  if (data is String && data.trim().isEmpty) {
    return const <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '生成分镜表',
        detail: '当前 storyboardTable 为空，适合先用分镜表子代理补结构。',
        flowKey: 'storyboardTable',
        subAgentTool: 'run_sub_agent_storyboard_table',
        prompt: '请先产出结构化 storyboardTable，并保持字段清晰可回写。',
      ),
    ];
  }
  if (!_hasStoryboardTableData(data)) {
    return const <ProductionWorkspaceRecipe>[];
  }
  final assetArgs = _storyboardTableRelatedAssetsArgs(data);
  final storyboardIds = extractProductionStoryboardIds(data);
  final storyboardArgs = buildProductionStoryboardReviewArgs(
    ids: storyboardIds,
  );
  return <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: '审核分镜表',
      detail: '分镜表已有内容，先做监督审核可避免把错误结构继续放大到 storyboard。',
      flowKey: 'storyboardTable',
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: '请审核当前分镜表，重点检查覆盖度、资产关联与拆分粒度。',
    ),
    ProductionWorkspaceRecipe(
      title: '核对关联资产',
      detail: assetArgs.containsKey('ids')
          ? '优先只看当前分镜窗口实际引用的资产，减少无关素材上下文。'
          : '当前窗口暂未解析出关联资产 ID，退回紧凑 assets 摘要读取。',
      flowKey: 'assets',
      domainTool: 'get_flowData',
      domainArgs: assetArgs,
    ),
    ProductionWorkspaceRecipe(
      title: '切回分镜结果',
      detail: storyboardIds.isEmpty
          ? '分镜表已有内容，可继续查看 storyboard 画面结果是否跟上。'
          : '优先只回看当前分镜表窗口对应的 ${storyboardIds.length} 个镜头，避免退回通用分镜摘要。',
      flowKey: 'storyboard',
      domainTool: 'get_flowData',
      domainArgs: storyboardArgs,
    ),
    ProductionWorkspaceRecipe(
      title: '抽样读取分镜表',
      detail: '先只看前 8 行关键列，通常足够判断是否继续审核或回写。',
      flowKey: 'storyboardTable',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(),
    ),
  ];
}

Map<String, dynamic> _scriptPlanCompactArgs() => <String, dynamic>{
  'key': 'scriptPlan',
  'maxChars': 2200,
};

Map<String, dynamic> _assetsCompactArgs() => <String, dynamic>{
  'key': 'assets',
  'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
  'limit': 24,
};

Map<String, dynamic> _storyboardTableRelatedAssetsArgs(Object? data) {
  return buildProductionFlowAssetArgs(data);
}

bool _hasStoryboardTableData(Object? data) {
  if (data is String) return data.trim().isNotEmpty;
  if (data is Map<String, dynamic>) {
    final rows = data['rows'];
    return rows is List && rows.isNotEmpty;
  }
  return false;
}

List<ProductionWorkspaceRecipe> _buildSupervisionRecipes(
  ProductionSupervisionReview review,
) {
  final summary = review.summary.isEmpty ? '按审核结论继续推进。' : review.summary;
  final storyboardFocus = summarizeProductionStoryboardFocusIds(
    review.storyboardIds,
  );
  final reviewScope = summarizeProductionStoryboardReviewScope(
    review.storyboardIds,
  );
  switch (review.nextAction) {
    case 'revise_scriptPlan':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '修导演计划',
          detail: '审核结论：$summary',
          flowKey: 'scriptPlan',
          subAgentTool: 'run_sub_agent_director_plan',
          prompt: '请根据最近审核意见修订 scriptPlan，优先解决：$summary',
        ),
        ProductionWorkspaceRecipe(
          title: '回看剧本依据',
          detail:
              '修订前先只回看${summarizeProductionPlanningScriptWindow()}，避免为 scriptPlan 扩读整段剧本。',
          flowKey: 'script',
          domainTool: 'get_flowData',
          domainArgs: buildProductionPlanningScriptArgs(),
        ),
        ProductionWorkspaceRecipe(
          title: '复查资产支撑',
          detail: '导演计划常先卡在资产准备，先看 assets 能减少返工。',
          flowKey: 'assets',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewAssetArgs(review),
        ),
      ];
    case 'check_assets':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '核对资产支撑',
          detail: '审核结论：$summary',
          flowKey: 'assets',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewAssetArgs(review),
        ),
      ];
    case 'check_storyboard':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '检查分镜结果',
          detail: storyboardFocus.isEmpty
              ? '审核结论：$summary'
              : '审核结论：$summary；优先只看$storyboardFocus。${reviewScope.isEmpty ? '' : ' $reviewScope。'}',
          flowKey: 'storyboard',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewStoryboardArgs(review),
        ),
        ProductionWorkspaceRecipe(
          title: '对照分镜表',
          detail: storyboardFocus.isEmpty
              ? '先复读关键列窗口，避免把整张分镜表重新带入上下文。'
              : '优先只复读$storyboardFocus对应的分镜表行，避免退回整表。',
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewStoryboardTableArgs(review),
        ),
        ProductionWorkspaceRecipe(
          title: '回看剧本依据',
          detail: reviewScope.isEmpty
              ? '需要时再回看紧凑剧本窗口，确认镜头依据。'
              : '如需核对镜头依据，优先只用局部范围：$reviewScope。',
          flowKey: 'script',
          domainTool: 'get_flowData',
          domainArgs: buildProductionScriptReviewArgs(review: review),
        ),
      ];
    case 'revise_storyboardTable':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '修分镜表',
          detail: '审核结论：$summary',
          flowKey: 'storyboardTable',
          subAgentTool: 'run_sub_agent_storyboard_table',
          prompt:
              '请根据最近审核意见修订 storyboardTable。${buildProductionStoryboardTableRevisionPrompt(review)}',
        ),
        ProductionWorkspaceRecipe(
          title: '抽样复读分镜表',
          detail: review.storyboardIds.isEmpty
              ? '先读取关键列窗口，避免把整张表反复带入上下文。'
              : '先只复读审核聚焦镜头对应的分镜表行，避免回到整表窗口。',
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewStoryboardTableArgs(review),
        ),
      ];
    case 'check_script':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '回看剧本依据',
          detail: reviewScope.isEmpty
              ? '审核结论：$summary'
              : '审核结论：$summary；优先只用局部范围：$reviewScope。',
          flowKey: 'script',
          domainTool: 'get_flowData',
          domainArgs: buildProductionScriptReviewArgs(review: review),
        ),
      ];
    case 'generate_storyboard':
      final storyboardArgs = buildProductionReviewStoryboardGenerationArgs(
        review,
      );
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '继续生成分镜图',
          detail: reviewScope.isEmpty
              ? '审核结论：$summary'
              : '审核结论：$summary；$reviewScope。',
          flowKey: 'storyboard',
          domainTool: 'get_flowData',
          domainArgs: storyboardArgs,
          subAgentTool: 'run_sub_agent_storyboard_gen',
          prompt:
              '请基于最近审核结论继续推进 storyboard。${buildProductionStoryboardGenerationPrompt(storyboardIds: review.storyboardIds, summary: summary)}',
        ),
        ProductionWorkspaceRecipe(
          title: '对照分镜表',
          detail: storyboardFocus.isEmpty
              ? '补图前先复读关键列窗口，避免为整批镜头重建上下文。'
              : '补图前先只复读$storyboardFocus对应的分镜表行。',
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewStoryboardTableArgs(review),
        ),
      ];
    default:
      return const <ProductionWorkspaceRecipe>[];
  }
}
