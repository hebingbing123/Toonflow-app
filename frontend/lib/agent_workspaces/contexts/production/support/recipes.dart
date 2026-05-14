part of '../support.dart';

List<ProductionWorkspaceArgumentSuggestion>
buildProductionActionArgumentSuggestions({
  required AppLocalizations l10n,
  required String? selectedTool,
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
  Map<String, dynamic>? toolArguments,
}) {
  final normalizedSelectedTool = selectedTool?.trim() ?? '';
  final flowData = _resolveProductionFlowData(
    toolName: toolName,
    suggestedFlowKey: suggestedFlowKey,
    result: result,
  );
  switch (normalizedSelectedTool) {
    case 'add_deriveAsset':
      return _buildAddDeriveAssetSuggestions(l10n, flowData);
    case 'del_deriveAsset':
      return _buildDeleteDeriveAssetSuggestions(l10n, flowData);
    case 'generate_deriveAsset':
      return _buildIdSuggestions(
        l10n,
        extractProductionActionCandidateIds(
          selectedTool: selectedTool,
          toolName: toolName,
          suggestedFlowKey: suggestedFlowKey,
          result: result,
          toolArguments: toolArguments,
        ),
      );
    case 'generate_storyboard':
      return _buildIdSuggestions(
        l10n,
        extractProductionActionCandidateIds(
          selectedTool: selectedTool,
          toolName: toolName,
          suggestedFlowKey: suggestedFlowKey,
          result: result,
          toolArguments: toolArguments,
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
  AppLocalizations l10n,
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
        label: l10n.agentWorkspaceProductionArgSuggestAddTo(
          '${parentId.toInt()}',
        ),
        payload: <String, dynamic>{
          'assetsId': parentId.toInt(),
          'id': null,
          'name': name == null || name.isEmpty
              ? l10n.agentWorkspaceProductionArgSuggestDeriveNameFallback
              : l10n.agentWorkspaceProductionFlowRecipeArgDeriveNameFromParent(
                  name,
                ),
          'desc': '',
        },
      ),
    );
  }
  return suggestions;
}

List<String> _productionAssetFields() => <String>[
  'id',
  'name',
  'type',
  'src',
  'flowId',
  'derive',
];

Map<String, dynamic> _productionAssetsCompactArgs() => <String, dynamic>{
  'key': 'assets',
  'fields': _productionAssetFields(),
  'limit': 24,
};

int _productionAssetTypeOrder(String value) {
  return switch (value) {
    'role' => 0,
    'scene' => 1,
    'tool' => 2,
    _ => 99,
  };
}

String _normalizeProductionAssetType(Object? value) {
  final normalized = switch (value) {
    String text => text.trim().toLowerCase(),
    _ => '',
  };
  return switch (normalized) {
    'role' || 'roles' || 'character' || 'characters' => 'role',
    'scene' || 'scenes' || 'location' || 'locations' => 'scene',
    'tool' || 'tools' || 'prop' || 'props' => 'tool',
    _ => '',
  };
}

List<String> productionStoryboardFields() => <String>[
  'id',
  'index',
  'duration',
  'prompt',
  'src',
  'state',
  'flowId',
  'associateAssetsIds',
  'shouldGenerateImage',
];

Map<String, dynamic> buildProductionStoryboardCompactArgs() =>
    <String, dynamic>{
      'key': 'storyboard',
      'fields': productionStoryboardFields(),
      'limit': 24,
    };

List<String> productionStoryboardTableFields() => <String>[
  'id',
  'description',
  'scene',
  'duration',
  'camera',
  'associateAssetsIds',
];

Map<String, dynamic> buildProductionStoryboardTableReadArgs({
  List<int> ids = const <int>[],
  int rowStart = 1,
  int rowCount = 8,
}) {
  final payload = <String, dynamic>{
    'key': 'storyboardTable',
    'fields': productionStoryboardTableFields(),
  };
  if (ids.isNotEmpty) {
    payload['ids'] = ids;
  } else {
    payload['rowStart'] = rowStart;
    payload['rowCount'] = rowCount;
  }
  return payload;
}

List<String> productionStoryboardReviewFields() => <String>[
  'id',
  'index',
  'duration',
  'src',
  'state',
  'associateAssetsIds',
  'shouldGenerateImage',
];

Map<String, dynamic> buildProductionStoryboardReviewArgs({
  List<int> ids = const <int>[],
}) {
  final payload = <String, dynamic>{
    'key': 'storyboard',
    'fields': productionStoryboardReviewFields(),
  };
  if (ids.isNotEmpty) {
    payload['ids'] = ids;
  } else {
    payload['limit'] = 12;
  }
  return payload;
}

List<String> productionStoryboardGenerationFields() => <String>[
  'id',
  'index',
  'src',
  'state',
  'associateAssetsIds',
  'shouldGenerateImage',
];

Map<String, dynamic> buildProductionStoryboardGenerationArgs({
  List<int> ids = const <int>[],
}) {
  final payload = <String, dynamic>{
    'key': 'storyboard',
    'fields': productionStoryboardGenerationFields(),
  };
  if (ids.isNotEmpty) {
    payload['ids'] = ids;
  } else {
    payload['limit'] = 12;
  }
  return payload;
}

List<ProductionWorkspaceArgumentSuggestion> _buildDeleteDeriveAssetSuggestions(
  AppLocalizations l10n,
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
          label: l10n.agentWorkspaceProductionArgSuggestDelete(
            '${deriveId.toInt()}',
          ),
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

List<ProductionWorkspaceArgumentSuggestion> _buildIdSuggestions(
  AppLocalizations l10n,
  List<int> ids,
) {
  if (ids.isEmpty) return const <ProductionWorkspaceArgumentSuggestion>[];
  return <ProductionWorkspaceArgumentSuggestion>[
    ProductionWorkspaceArgumentSuggestion(
      label: l10n.agentWorkspaceProductionArgSuggestFillFirst,
      payload: <String, dynamic>{'ids': ids.take(1).toList(growable: false)},
    ),
    if (ids.length > 1)
      ProductionWorkspaceArgumentSuggestion(
        label: l10n.agentWorkspaceProductionArgSuggestFillFirstThree,
        payload: <String, dynamic>{'ids': ids.take(3).toList(growable: false)},
      ),
    if (ids.length > 3)
      ProductionWorkspaceArgumentSuggestion(
        label: l10n.agentWorkspaceProductionArgSuggestFillAll,
        payload: <String, dynamic>{'ids': ids},
      ),
  ];
}

Map<String, dynamic> _buildProductionGenerateAssetsSubAgentArgs({
  required String toolName,
  required String suggestedFlowKey,
  required Object? result,
  Map<String, dynamic>? toolArguments,
}) {
  final candidateIds = extractProductionActionCandidateIds(
    selectedTool: 'generate_deriveAsset',
    toolName: toolName,
    suggestedFlowKey: suggestedFlowKey,
    result: result,
    toolArguments: toolArguments,
  );
  if (candidateIds.isNotEmpty) {
    return buildProductionSubAgentArgs(assetIds: candidateIds);
  }
  if (toolName == 'get_flowData' &&
      suggestedFlowKey == 'assets' &&
      result is Map<String, dynamic>) {
    final pendingIds = extractProductionPendingDeriveAssetIds(result['data']);
    if (pendingIds.isNotEmpty) {
      return buildProductionSubAgentArgs(assetIds: pendingIds);
    }
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _buildProductionDeriveAssetsSubAgentArgs({
  required String toolName,
  required String suggestedFlowKey,
  required Object? result,
}) {
  if (toolName != 'get_flowData' || result is! Map<String, dynamic>) {
    return const <String, dynamic>{};
  }
  switch (suggestedFlowKey) {
    case 'scriptPlan':
      return _buildProductionSubAgentArgsFromAssetReadArgs(
        buildProductionScriptPlanAssetArgs(result['data']),
      );
    case 'storyboard':
    case 'storyboardTable':
      return buildProductionSubAgentArgs(
        assetIds: extractProductionReferencedAssetIds(result['data']),
      );
    case 'assets':
      final pendingIds = extractProductionPendingDeriveAssetIds(result['data']);
      if (pendingIds.isNotEmpty) {
        return buildProductionSubAgentArgs(assetIds: pendingIds);
      }
      return const <String, dynamic>{};
    default:
      return const <String, dynamic>{};
  }
}

Map<String, dynamic> _buildProductionStoryboardSubAgentArgs({
  required String toolName,
  required String suggestedFlowKey,
  required Object? result,
  Map<String, dynamic>? toolArguments,
}) {
  final storyboardIds = extractProductionActionCandidateIds(
    selectedTool: 'generate_storyboard',
    toolName: toolName,
    suggestedFlowKey: suggestedFlowKey,
    result: result,
    toolArguments: toolArguments,
  );
  if (storyboardIds.isNotEmpty) {
    final flowData = result is Map<String, dynamic> ? result['data'] : null;
    return buildProductionSubAgentArgs(
      storyboardIds: storyboardIds,
      assetIds: extractProductionReferencedAssetIdsForStoryboardIds(
        flowData,
        storyboardIds,
      ),
    );
  }
  if (toolName == 'get_flowData' &&
      suggestedFlowKey == 'storyboard' &&
      result is Map<String, dynamic>) {
    final flowData = result['data'];
    final missingIds = extractProductionStoryboardMissingImageIds(flowData);
    if (missingIds.isNotEmpty) {
      return buildProductionSubAgentArgs(
        storyboardIds: missingIds,
        assetIds: extractProductionReferencedAssetIdsForStoryboardIds(
          flowData,
          missingIds,
        ),
      );
    }
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _buildProductionStoryboardTableSubAgentArgs({
  required String toolName,
  required String suggestedFlowKey,
  required Object? result,
  Map<String, dynamic>? toolArguments,
}) {
  final storyboardIds = extractProductionStoryboardPromptScopeIds(
    toolName,
    toolArguments,
  );
  if (storyboardIds.isNotEmpty) {
    return buildProductionSubAgentArgs(storyboardIds: storyboardIds);
  }
  if (toolName == 'get_flowData' && result is Map<String, dynamic>) {
    if (suggestedFlowKey == 'storyboard') {
      final missingIds = extractProductionStoryboardMissingImageIds(
        result['data'],
      );
      if (missingIds.isNotEmpty) {
        return buildProductionSubAgentArgs(storyboardIds: missingIds);
      }
    }
    if (suggestedFlowKey == 'storyboardTable') {
      final ids = extractProductionStoryboardIds(result['data']);
      if (ids.isNotEmpty) {
        return buildProductionSubAgentArgs(storyboardIds: ids);
      }
    }
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _buildProductionDirectorPlanSubAgentArgs({
  required String toolName,
  required String suggestedFlowKey,
  required Object? result,
}) {
  if (toolName != 'get_flowData' || result is! Map<String, dynamic>) {
    return const <String, dynamic>{};
  }
  switch (suggestedFlowKey) {
    case 'scriptPlan':
      return _buildProductionSubAgentArgsFromAssetReadArgs(
        buildProductionScriptPlanAssetArgs(result['data']),
      );
    case 'storyboard':
      final missingIds = extractProductionStoryboardMissingImageIds(
        result['data'],
      );
      final storyboardIds = missingIds.isNotEmpty
          ? missingIds
          : extractProductionStoryboardIds(result['data']);
      return buildProductionSubAgentArgs(
        storyboardIds: storyboardIds,
        assetIds: extractProductionReferencedAssetIds(result['data']),
      );
    case 'assets':
      final pendingIds = extractProductionPendingDeriveAssetIds(result['data']);
      if (pendingIds.isNotEmpty) {
        return buildProductionSubAgentArgs(assetIds: pendingIds);
      }
      return const <String, dynamic>{};
    default:
      return const <String, dynamic>{};
  }
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

List<int> extractProductionPendingDeriveAssetIds(Object? value) {
  if (value is! List) return const <int>[];
  final ids = <int>{};
  for (final row in value.whereType<Map<String, dynamic>>()) {
    final derive = row['derive'];
    if (derive is! List) continue;
    for (final child in derive.whereType<Map<String, dynamic>>()) {
      final childId = _parseLooseInt(
        child['id'] ??
            child['numeric_id'] ??
            child['numericId'] ??
            child['assetId'] ??
            child['assetsId'],
      );
      if (childId <= 0 || productionFlowEntryHasMediaResult(child)) {
        continue;
      }
      ids.add(childId);
    }
  }
  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

List<int> _extractEntityIds(Object? value) {
  if (value is! List) return const <int>[];
  final ids = <int>{};
  for (final row in value.whereType<Map<String, dynamic>>()) {
    final rawId =
        row['id'] ??
        row['numeric_id'] ??
        row['numericId'] ??
        row['storyboardId'] ??
        row['assetId'] ??
        row['assetsId'];
    final parsedId = _parseLooseInt(rawId);
    if (parsedId > 0) {
      ids.add(parsedId);
    }
  }
  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

List<int> _extractToolScopedIds(Object? value) {
  if (value is! List) return const <int>[];
  final ids = value.map(_parseLooseInt).where((id) => id > 0).toSet().toList();
  ids.sort();
  return ids;
}

List<int> _extractPromptScopedIds({
  required String selectedTool,
  required String toolName,
  required Map<String, dynamic>? toolArguments,
}) {
  if (toolArguments == null || toolArguments.isEmpty) {
    return const <int>[];
  }
  if (toolName == 'run_sub_agent_generate_assets' &&
      selectedTool == 'generate_deriveAsset') {
    return _extractPromptIds(
      toolArguments,
      explicitKey: 'assetIds',
      noun: 'asset',
    );
  }
  if (toolName == 'run_sub_agent_storyboard_gen' &&
      selectedTool == 'generate_storyboard') {
    return _extractPromptIds(
      toolArguments,
      explicitKey: 'storyboardIds',
      noun: 'storyboard',
    );
  }
  if (toolName == 'run_sub_agent_storyboard_panel' &&
      selectedTool == 'generate_storyboard') {
    return _extractPromptIds(
      toolArguments,
      explicitKey: 'storyboardIds',
      noun: 'storyboard',
    );
  }
  return const <int>[];
}

List<int> extractProductionStoryboardPromptScopeIds(
  String toolName,
  Map<String, dynamic>? toolArguments,
) {
  final normalizedToolName = toolName.trim();
  if (normalizedToolName != 'run_sub_agent_storyboard_gen' &&
      normalizedToolName != 'run_sub_agent_storyboard_panel' &&
      normalizedToolName != 'run_sub_agent_storyboard_table') {
    return const <int>[];
  }
  return _extractPromptIds(
    toolArguments ?? const <String, dynamic>{},
    explicitKey: 'storyboardIds',
    noun: 'storyboard',
  );
}

List<int> _extractPromptIds(
  Map<String, dynamic> arguments, {
  required String explicitKey,
  required String noun,
}) {
  final explicitIds = _extractToolScopedIds(arguments[explicitKey]);
  if (explicitIds.isNotEmpty) {
    return explicitIds;
  }
  final prompt = (arguments['prompt'] as String?)?.trim() ?? '';
  if (prompt.isEmpty) {
    return const <int>[];
  }
  final ids = <int>{};
  final patterns = <RegExp>[
    RegExp('$noun\\s+ids?\\s*=\\s*([\\d,\\s]+)', caseSensitive: false),
    RegExp('$noun\\s*#([\\d,\\s]+)', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    for (final match in pattern.allMatches(prompt)) {
      final scope = match.group(1) ?? '';
      for (final idMatch in RegExp(r'\d+').allMatches(scope)) {
        final id = int.tryParse(idMatch.group(0) ?? '');
        if (id != null && id > 0) {
          ids.add(id);
        }
      }
    }
  }
  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

List<String> _splitMarkdownTableRow(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) {
    return const <String>[];
  }
  return trimmed
      .substring(1, trimmed.length - 1)
      .split('|')
      .map((cell) => cell.trim())
      .toList(growable: false);
}

String _normalizeStoryboardTableColumn(String column) {
  switch (column.trim()) {
    case '序号':
    case 'id':
      return 'id';
    case '画面描述':
    case 'description':
      return 'description';
    case '场景':
    case 'scene':
      return 'scene';
    case '时长':
    case 'duration':
      return 'duration';
    case '景别':
    case 'camera':
      return 'camera';
    case '关联资产ID':
    case '关联资产Ids':
    case 'associateAssetsIds':
      return 'associateAssetsIds';
    default:
      return column.trim();
  }
}
