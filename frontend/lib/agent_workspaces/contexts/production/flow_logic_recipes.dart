part of 'flow_logic.dart';

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
      final raw = row['url'] ?? row['imageUrl'];
      return raw is! String || raw.trim().isEmpty;
    }).length;
    if (withoutUrl > 0) {
      return <ProductionWorkspaceRecipe>[
        const ProductionWorkspaceRecipe(
          title: '继续资产生成',
          detail: '仍有素材缺少图像结果，适合直接运行素材生成子代理。',
          flowKey: 'assets',
          subAgentTool: 'run_sub_agent_generate_assets',
          prompt: '请基于当前 assets flow 优先补齐缺少图像结果的素材，并执行最小可行生成动作。',
        ),
        const ProductionWorkspaceRecipe(
          title: '刷新分镜需求',
          detail: '素材缺口补齐后通常需要回看 storyboard 是否还能沿用当前方案。',
          flowKey: 'storyboard',
          domainTool: 'get_flowData',
        ),
      ];
    }
  }
  return const <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: '检查分镜 flow',
      detail: '资产已具备基础结果，可切到 storyboard 评估镜头生成状态。',
      flowKey: 'storyboard',
      domainTool: 'get_flowData',
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
    final withoutImage = rows.where((row) {
      final raw = row['url'];
      return raw is! String || raw.trim().isEmpty;
    }).length;
    if (withoutImage > 0) {
      return const <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: '继续补齐分镜图',
          detail: '仍有分镜缺少画面结果，继续推进 storyboard 生成更合适。',
          flowKey: 'storyboard',
          subAgentTool: 'run_sub_agent_storyboard_gen',
          prompt: '请优先补齐缺少画面结果的 storyboard 项，并执行最小可行生成动作。',
        ),
        ProductionWorkspaceRecipe(
          title: '检查分镜表',
          detail: '必要时切到 storyboardTable 审阅结构化镜头表后再回写。',
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
        ),
      ];
    }
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
  return const <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: '检查资产落地',
      detail: '导演计划已有内容，下一步通常是核对 assets 是否支撑执行。',
      flowKey: 'assets',
      domainTool: 'get_flowData',
    ),
    ProductionWorkspaceRecipe(
      title: '检查分镜落地',
      detail: '如计划已定，可直接回看 storyboard 的实际生成状态。',
      flowKey: 'storyboard',
      domainTool: 'get_flowData',
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
  return const <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: '切回分镜结果',
      detail: '分镜表已有内容，可继续查看 storyboard 画面结果是否跟上。',
      flowKey: 'storyboard',
      domainTool: 'get_flowData',
    ),
  ];
}

