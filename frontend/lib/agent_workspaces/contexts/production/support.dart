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
        row['numeric_id'] ??
        row['numericId'] ??
        row['storyboardId'] ??
        row['assetId'] ??
        row['assetsId'];
    if (rawId is num) {
      ids.add(rawId.toInt());
    }
  }
  return ids.toSet().toList(growable: false);
}

