part of 'flow_logic.dart';

List<ProductionWorkspaceStage> buildProductionWorkspaceStages({
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
}) {
  final normalizedTool = toolName?.trim() ?? '';
  final normalizedKey = suggestedFlowKey?.trim() ?? '';
  final flowSnapshot = _resolveProductionWorkspaceFlowSnapshot(
    toolName: toolName,
    suggestedFlowKey: suggestedFlowKey,
    result: result,
  );
  final activeKey = _resolveProductionStageActiveKey(
    toolName: normalizedTool,
    suggestedFlowKey: normalizedKey,
  );

  return <ProductionWorkspaceStage>[
    _buildScriptPlanStage(
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
    ),
    _buildAssetsStage(
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
    ),
    _buildStoryboardTableStage(
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
    ),
    _buildStoryboardStage(
      activeKey: activeKey,
      flowSnapshot: flowSnapshot,
      toolName: normalizedTool,
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
}) {
  if (toolName == 'get_flowData' && suggestedFlowKey.isNotEmpty) {
    return suggestedFlowKey;
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
}) {
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
    return ProductionWorkspaceStage(
      title: '导演计划',
      flowKey: 'scriptPlan',
      statusLabel: '已就绪',
      detail:
          '已读取 scriptPlan，当前约 ${trimmed.length} 字，可继续核对 assets 与 storyboard。',
      domainTool: 'get_flowData',
    );
  }
  if (activeKey == 'scriptPlan' || toolName == 'run_sub_agent_director_plan') {
    return const ProductionWorkspaceStage(
      title: '导演计划',
      flowKey: 'scriptPlan',
      statusLabel: '建议刷新',
      detail: '导演计划刚变更或正在处理，建议重新读取 scriptPlan 确认最新内容。',
      domainTool: 'get_flowData',
    );
  }
  return const ProductionWorkspaceStage(
    title: '导演计划',
    flowKey: 'scriptPlan',
    statusLabel: '待读取',
    detail: '先读取 scriptPlan，确认制作优先级与执行顺序。',
    domainTool: 'get_flowData',
  );
}

ProductionWorkspaceStage _buildAssetsStage({
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
}) {
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
      final raw = row['url'] ?? row['imageUrl'];
      return raw is String && raw.trim().isNotEmpty;
    }).length;
    final missingCount = rows.length - readyCount;
    if (missingCount > 0) {
      return ProductionWorkspaceStage(
        title: '资产准备',
        flowKey: 'assets',
        statusLabel: '需补图',
        detail: '共 ${rows.length} 项资产，仍有 $missingCount 项缺少图像结果，适合继续运行素材生成。',
        subAgentTool: 'run_sub_agent_generate_assets',
        prompt: '请基于当前 assets flow 优先补齐缺少图像结果的素材，并执行最小可行生成动作。',
      );
    }
    return ProductionWorkspaceStage(
      title: '资产准备',
      flowKey: 'assets',
      statusLabel: '已齐备',
      detail: '共 ${rows.length} 项资产，图像结果已齐，可继续检查 storyboard 与导演计划。',
      domainTool: 'get_flowData',
    );
  }
  if (activeKey == 'assets' ||
      toolName == 'generate_deriveAsset' ||
      toolName == 'add_deriveAsset' ||
      toolName == 'del_deriveAsset' ||
      toolName == 'run_sub_agent_derive_assets' ||
      toolName == 'run_sub_agent_generate_assets') {
    return const ProductionWorkspaceStage(
      title: '资产准备',
      flowKey: 'assets',
      statusLabel: '建议刷新',
      detail: '资产相关动作刚执行，建议重新读取 assets 确认最新结果。',
      domainTool: 'get_flowData',
    );
  }
  return const ProductionWorkspaceStage(
    title: '资产准备',
    flowKey: 'assets',
    statusLabel: '待读取',
    detail: '读取 assets flow 后可判断是否需要继续做衍生资产或素材生成。',
    domainTool: 'get_flowData',
  );
}

ProductionWorkspaceStage _buildStoryboardTableStage({
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
}) {
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
    return ProductionWorkspaceStage(
      title: '分镜表',
      flowKey: 'storyboardTable',
      statusLabel: '已就绪',
      detail:
          'storyboardTable 已有内容，约 ${trimmed.length} 字，可继续检查 storyboard 画面结果。',
      domainTool: 'get_flowData',
    );
  }
  if (activeKey == 'storyboardTable' ||
      toolName == 'run_sub_agent_storyboard_table') {
    return const ProductionWorkspaceStage(
      title: '分镜表',
      flowKey: 'storyboardTable',
      statusLabel: '建议刷新',
      detail: '分镜表刚变更或正在处理，建议重新读取 storyboardTable。',
      domainTool: 'get_flowData',
    );
  }
  return const ProductionWorkspaceStage(
    title: '分镜表',
    flowKey: 'storyboardTable',
    statusLabel: '待读取',
    detail: '需要时可读取 storyboardTable 审阅结构化镜头表。',
    domainTool: 'get_flowData',
  );
}

ProductionWorkspaceStage _buildStoryboardStage({
  required String? activeKey,
  required Map<String, Object?> flowSnapshot,
  required String toolName,
}) {
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
    final readyCount = rows.where((row) {
      final raw = row['url'];
      return raw is String && raw.trim().isNotEmpty;
    }).length;
    final missingCount = rows.length - readyCount;
    if (missingCount > 0) {
      return ProductionWorkspaceStage(
        title: '分镜画面',
        flowKey: 'storyboard',
        statusLabel: '需补帧',
        detail: '共 ${rows.length} 个镜头，仍有 $missingCount 个缺少画面结果，适合继续生成分镜。',
        subAgentTool: 'run_sub_agent_storyboard_gen',
        prompt: '请优先补齐缺少画面结果的 storyboard 项，并执行最小可行生成动作。',
      );
    }
    return ProductionWorkspaceStage(
      title: '分镜画面',
      flowKey: 'storyboard',
      statusLabel: '已完成',
      detail: '共 ${rows.length} 个镜头，画面结果齐备，可准备写回或继续导演计划。',
      domainTool: 'get_flowData',
    );
  }
  if (activeKey == 'storyboard' ||
      toolName == 'generate_storyboard' ||
      toolName == 'run_sub_agent_storyboard_gen' ||
      toolName == 'run_sub_agent_storyboard_panel') {
    return const ProductionWorkspaceStage(
      title: '分镜画面',
      flowKey: 'storyboard',
      statusLabel: '建议刷新',
      detail: '分镜动作刚执行，建议重新读取 storyboard 再决定是否写回。',
      domainTool: 'get_flowData',
    );
  }
  return const ProductionWorkspaceStage(
    title: '分镜画面',
    flowKey: 'storyboard',
    statusLabel: '待读取',
    detail: '读取 storyboard 后可判断是否需要继续补图或直接写回结果。',
    domainTool: 'get_flowData',
  );
}
