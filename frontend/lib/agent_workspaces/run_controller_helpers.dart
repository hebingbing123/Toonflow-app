part of 'run_controller.dart';

int? _parsePositiveInt(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0) return null;
  return value;
}

Map<String, dynamic> _buildScriptSubAgentArguments({
  required String toolName,
  required String prompt,
  required int? scriptId,
  required String? lastToolName,
  required Object? lastToolResult,
  required Map<String, dynamic>? lastToolArguments,
}) {
  final arguments = <String, dynamic>{'prompt': prompt, 'scriptId': scriptId}
    ..removeWhere((_, Object? value) => value == null);
  final scope = _buildScriptSubAgentScope(
    toolName: toolName,
    lastToolName: lastToolName,
    lastToolResult: lastToolResult,
    lastToolArguments: lastToolArguments,
  );
  arguments.addAll(scope);
  return arguments;
}

Map<String, dynamic> _buildScriptSubAgentScope({
  required String toolName,
  required String? lastToolName,
  required Object? lastToolResult,
  required Map<String, dynamic>? lastToolArguments,
}) {
  final scope = <String, dynamic>{};
  final focusSections = switch (toolName) {
    'run_sub_agent_storySkeleton' => <String>['storySkeleton'],
    'run_sub_agent_adaptationStrategy' => <String>[
      'storySkeleton',
      'adaptationStrategy',
    ],
    'run_sub_agent_script' => <String>[
      'storySkeleton',
      'adaptationStrategy',
      'script',
    ],
    'run_supervision_agent' => <String>[
      'storySkeleton',
      'adaptationStrategy',
      'script',
    ],
    _ => const <String>[],
  };
  if (focusSections.isNotEmpty) {
    scope['focusSections'] = focusSections;
  }

  final novelIds = _extractNovelIdsFromWorkspaceContext(
    lastToolName: lastToolName,
    lastToolResult: lastToolResult,
    lastToolArguments: lastToolArguments,
  );
  if (novelIds.isNotEmpty) {
    scope['novelIds'] = novelIds;
  }

  final relativeScriptOffset = _extractRelativeScriptOffset(lastToolArguments);
  if (relativeScriptOffset != null) {
    scope['relativeScriptOffset'] = relativeScriptOffset;
  }
  return scope;
}

List<int> _extractNovelIdsFromWorkspaceContext({
  required String? lastToolName,
  required Object? lastToolResult,
  required Map<String, dynamic>? lastToolArguments,
}) {
  final ids = <int>{};
  final argumentNovelId = _toPositiveInt(lastToolArguments?['novelId']);
  if (argumentNovelId != null) {
    ids.add(argumentNovelId);
  }
  final normalizedToolName = lastToolName?.trim();
  if (normalizedToolName != 'get_novel_text' &&
      normalizedToolName != 'get_novel_events') {
    return ids.toList()..sort();
  }
  if (lastToolResult is! Map<String, dynamic>) {
    return ids.toList()..sort();
  }
  final items = lastToolResult['items'];
  if (items is! List) {
    return ids.toList()..sort();
  }
  for (final row in items.whereType<Map<String, dynamic>>()) {
    final novelId = _toPositiveInt(
      row['numeric_id'] ?? row['numericId'] ?? row['id'],
    );
    if (novelId != null) {
      ids.add(novelId);
    }
  }
  final sortedIds = ids.toList()..sort();
  return sortedIds;
}

int? _extractRelativeScriptOffset(Map<String, dynamic>? arguments) {
  final value = arguments?['relativeOffset'];
  if (value is num) {
    final offset = value.toInt();
    if (offset == -1 || offset == 1) {
      return offset;
    }
  }
  return null;
}

int? _toPositiveInt(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num) {
    final normalized = value.toInt();
    if (normalized > 0) return normalized;
  }
  if (value is String) {
    final normalized = int.tryParse(value.trim());
    if (normalized != null && normalized > 0) {
      return normalized;
    }
  }
  return null;
}

Map<String, dynamic>? _parseJsonObject(
  String raw, {
  required String objectError,
  required String parseError,
  required WorkspaceRunErrorSink onErrorChanged,
}) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(normalized);
    if (decoded is! Map<String, dynamic>) {
      onErrorChanged(objectError);
      return null;
    }
    return decoded;
  } catch (_) {
    onErrorChanged(parseError);
    return null;
  }
}

void _prepareWorkspaceRunState({
  required WorkspaceRunStateReset clearWsLog,
  required WorkspaceRunStateReset resetWorkspaceOutputs,
  required WorkspaceRunErrorSink onErrorChanged,
}) {
  clearWsLog();
  resetWorkspaceOutputs();
  onErrorChanged(null);
}
