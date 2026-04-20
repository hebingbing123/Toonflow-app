// Flow snapshot analysis, stage builders, and recipe builders for the
// production workspace. Extracted into the production context package to keep
// individual files ≤800 lines.

import 'support.dart';
part 'flow_logic_recipes.dart';
part 'flow_logic_stages.dart';

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
