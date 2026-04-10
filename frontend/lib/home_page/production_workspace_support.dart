class ProductionWorkspaceRecipe {
  const ProductionWorkspaceRecipe({
    required this.title,
    required this.detail,
    required this.flowKey,
    this.domainTool,
    this.subAgentTool,
    this.prompt,
  });

  final String title;
  final String detail;
  final String flowKey;
  final String? domainTool;
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
    this.subAgentTool,
    this.prompt,
  });

  final String title;
  final String flowKey;
  final String statusLabel;
  final String detail;
  final String? domainTool;
  final String? subAgentTool;
  final String? prompt;
}

class ProductionWorkspaceArgumentSuggestion {
  const ProductionWorkspaceArgumentSuggestion({
    required this.label,
    required this.payload,
  });

  final String label;
  final Map<String, dynamic> payload;
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

  Object? data = result['data'];
  if (normalizedToolName == 'get_flowData') {
    switch (normalizedSelectedTool) {
      case 'generate_deriveAsset':
        if (normalizedKey != 'assets') return const <int>[];
        return _extractDeriveAssetIds(data);
      case 'generate_storyboard':
        if (normalizedKey != 'storyboard') return const <int>[];
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
        return _extractEntityIds(data['storyboard']);
      default:
        return const <int>[];
    }
  }

  return const <int>[];
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

List<int> _extractEntityIds(Object? value) {
  if (value is! List) return const <int>[];
  final ids = <int>[];
  for (final row in value.whereType<Map<String, dynamic>>()) {
    final rawId =
        row['id'] ??
        row['legacy_id'] ??
        row['legacyId'] ??
        row['storyboardId'] ??
        row['assetId'] ??
        row['assetsId'];
    if (rawId is num) {
      ids.add(rawId.toInt());
    }
  }
  return ids.toSet().toList(growable: false);
}

List<String> summarizeProductionResultSnapshot(
  String? toolName,
  Object? result,
) {
  final normalizedTool = toolName?.trim() ?? '';
  if (result is! Map<String, dynamic>) {
    if (result is List) {
      return <String>['返回列表 ${result.length} 项'];
    }
    if (result is String && result.trim().isNotEmpty) {
      return <String>['返回文本 ${result.trim().length} 字'];
    }
    return const <String>[];
  }

  final data = result['data'];
  if (normalizedTool == 'get_flowData' && data != null) {
    return summarizeProductionFlowValue(data);
  }

  if (result['items'] is List) {
    final items = result['items'] as List<dynamic>;
    return <String>['返回 items ${items.length} 项'];
  }

  final text = result['result'];
  if (text is String && text.trim().isNotEmpty) {
    return <String>['返回文本 ${text.trim().length} 字'];
  }

  return <String>['返回对象 keys=${result.keys.join(',')}'];
}

List<String> summarizeProductionFlowValue(Object? value) {
  if (value == null) {
    return const <String>['当前 flow 为空'];
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>['当前 flow 为空字符串'];
    }
    final lines = '\n'.allMatches(trimmed).length + 1;
    return <String>['文本 ${trimmed.length} 字', '$lines 行'];
  }
  if (value is List) {
    if (value.isEmpty) {
      return const <String>['当前列表为空'];
    }
    final first = value.first;
    if (first is Map<String, dynamic>) {
      final withUrl = value.whereType<Map<String, dynamic>>().where((entry) {
        final raw = entry['url'] ?? entry['imageUrl'] ?? entry['videoUrl'];
        return raw is String && raw.trim().isNotEmpty;
      }).length;
      final withPrompt = value.whereType<Map<String, dynamic>>().where((entry) {
        final raw = entry['prompt'];
        return raw is String && raw.trim().isNotEmpty;
      }).length;
      final states = value
          .whereType<Map<String, dynamic>>()
          .map((entry) {
            final raw = entry['state'];
            return raw is String ? raw.trim() : '';
          })
          .where((entry) => entry.isNotEmpty)
          .toSet()
          .length;
      final lines = <String>['列表 ${value.length} 项'];
      if (withPrompt > 0) lines.add('含提示词 $withPrompt 项');
      if (withUrl > 0) lines.add('含媒体地址 $withUrl 项');
      if (states > 0) lines.add('状态种类 $states 个');
      return lines;
    }
    return <String>['列表 ${value.length} 项'];
  }
  if (value is Map<String, dynamic>) {
    final lines = <String>['对象 keys=${value.keys.length} 个'];
    for (final entry in value.entries) {
      final child = entry.value;
      if (child is List) {
        lines.add('${entry.key}: ${child.length} 项');
      } else if (child is String && child.trim().isNotEmpty) {
        lines.add('${entry.key}: ${child.trim().length} 字');
      }
      if (lines.length >= 4) {
        break;
      }
    }
    return lines;
  }
  return <String>['返回 ${value.runtimeType}'];
}

List<ProductionWorkspaceRecipe> buildProductionWorkspaceRecipes({
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
}) {
  final normalizedTool = toolName?.trim() ?? '';
  final normalizedKey = suggestedFlowKey?.trim() ?? '';
  if (normalizedTool.isEmpty || result is! Map<String, dynamic>) {
    return const <ProductionWorkspaceRecipe>[];
  }

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
    return const <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '刷新分镜 flow',
        detail: '分镜生成动作已执行，先拉取最新 storyboard 再决定是否写回。',
        flowKey: 'storyboard',
        domainTool: 'get_flowData',
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
    return const <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: '刷新资产 flow',
        detail: '资产动作已执行，先拉取最新 assets 结果再决定是否写回。',
        flowKey: 'assets',
        domainTool: 'get_flowData',
      ),
      ProductionWorkspaceRecipe(
        title: '继续资产子代理',
        detail: '若仍缺素材，可直接衔接资产子代理推进下一轮生成。',
        flowKey: 'assets',
        subAgentTool: 'run_sub_agent_generate_assets',
        prompt: '请基于最新 assets flow 判断缺失素材，并执行下一轮最小可行生成动作。',
      ),
    ];
  }

  return const <ProductionWorkspaceRecipe>[];
}

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
        ProductionWorkspaceRecipe(
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
