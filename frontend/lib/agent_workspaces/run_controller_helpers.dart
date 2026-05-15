part of 'run_controller.dart';

class _ScriptAttachScope {
  const _ScriptAttachScope({
    required this.projectUuid,
    required this.projectNumeric,
    required this.workspaceUuid,
    required this.error,
  });

  final String? projectUuid;
  final int? projectNumeric;
  final String? workspaceUuid;
  final String? error;
}

class _ProductionAttachScope {
  const _ProductionAttachScope({
    required this.projectUuid,
    required this.projectNumeric,
    required this.scriptUuid,
    required this.scriptNumeric,
    required this.workspaceUuid,
    required this.error,
  });

  final String? projectUuid;
  final int? projectNumeric;
  final String? scriptUuid;
  final int? scriptNumeric;
  final String? workspaceUuid;
  final String? error;
}

void _putTrimmedIfPresent(
  Map<String, dynamic> payload,
  String key,
  String? value,
) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return;
  }
  payload[key] = normalized;
}

void _putPositiveIntIfPresent(
  Map<String, dynamic> payload,
  String key,
  int? value,
) {
  if (value == null || value <= 0) {
    return;
  }
  payload[key] = value;
}

({String? projectUuid, int? projectNumeric, String? error})
_parseProjectAttachInputs(
  WorkspaceInputController input,
  AppLocalizations l10n,
) {
  final uuidRaw = trimmedNonEmpty(input.projectUuidController.text);
  if (uuidRaw != null && !looksLikeUuid(uuidRaw)) {
    return (
      projectUuid: null,
      projectNumeric: null,
      error: l10n.agentWorkspaceRunProjectUuidInvalid,
    );
  }
  final numeric = parsePositiveInt(input.projectIdController.text);
  if (uuidRaw == null && numeric == null) {
    return (
      projectUuid: null,
      projectNumeric: null,
      error: l10n.agentWorkspaceRunProjectScopeRequired,
    );
  }
  return (projectUuid: uuidRaw, projectNumeric: numeric, error: null);
}

({String? workspaceUuid, String? error}) _parseOptionalWorkspaceUuid(
  WorkspaceInputController input,
  AppLocalizations l10n,
) {
  final raw = trimmedNonEmpty(input.workspaceUuidController.text);
  if (raw == null) return (workspaceUuid: null, error: null);
  if (!looksLikeUuid(raw)) {
    return (
      workspaceUuid: null,
      error: l10n.agentWorkspaceRunWorkspaceUuidInvalid,
    );
  }
  return (workspaceUuid: raw, error: null);
}

_ScriptAttachScope _readScriptAttachScope(
  WorkspaceInputController input,
  AppLocalizations l10n,
) {
  final proj = _parseProjectAttachInputs(input, l10n);
  if (proj.error != null) {
    return _ScriptAttachScope(
      projectUuid: null,
      projectNumeric: null,
      workspaceUuid: null,
      error: proj.error,
    );
  }
  final workspace = _parseOptionalWorkspaceUuid(input, l10n);
  return _ScriptAttachScope(
    projectUuid: proj.projectUuid,
    projectNumeric: proj.projectNumeric,
    workspaceUuid: workspace.workspaceUuid,
    error: workspace.error,
  );
}

({String? scriptUuid, int? scriptNumeric, String? error})
_parseScriptAttachInputs(
  WorkspaceInputController input,
  AppLocalizations l10n,
) {
  final uuidRaw = trimmedNonEmpty(input.scriptUuidController.text);
  if (uuidRaw != null && !looksLikeUuid(uuidRaw)) {
    return (
      scriptUuid: null,
      scriptNumeric: null,
      error: l10n.agentWorkspaceRunScriptUuidInvalid,
    );
  }
  final numeric = parsePositiveInt(input.scriptIdController.text);
  if (uuidRaw == null && numeric == null) {
    return (
      scriptUuid: null,
      scriptNumeric: null,
      error: l10n.agentWorkspaceRunScriptScopeRequired,
    );
  }
  return (scriptUuid: uuidRaw, scriptNumeric: numeric, error: null);
}

_ProductionAttachScope _readProductionAttachScope(
  WorkspaceInputController input,
  AppLocalizations l10n,
) {
  final scriptScope = _readScriptAttachScope(input, l10n);
  if (scriptScope.error != null) {
    return _ProductionAttachScope(
      projectUuid: null,
      projectNumeric: null,
      scriptUuid: null,
      scriptNumeric: null,
      workspaceUuid: null,
      error: scriptScope.error,
    );
  }
  final script = _parseScriptAttachInputs(input, l10n);
  return _ProductionAttachScope(
    projectUuid: scriptScope.projectUuid,
    projectNumeric: scriptScope.projectNumeric,
    scriptUuid: script.scriptUuid,
    scriptNumeric: script.scriptNumeric,
    workspaceUuid: scriptScope.workspaceUuid,
    error: script.error,
  );
}

Map<String, dynamic> _scriptAttachPayload({
  required String isolationKey,
  String? projectUuid,
  int? projectNumeric,
  String? workspaceUuid,
}) {
  return _attachScopePayload(
    isolationKey: isolationKey,
    projectUuid: projectUuid,
    projectNumeric: projectNumeric,
    workspaceUuid: workspaceUuid,
  );
}

Map<String, dynamic> _productionAttachPayload({
  required String isolationKey,
  String? projectUuid,
  int? projectNumeric,
  String? scriptUuid,
  int? scriptNumeric,
  String? workspaceUuid,
}) {
  final payload = _attachScopePayload(
    isolationKey: isolationKey,
    projectUuid: projectUuid,
    projectNumeric: projectNumeric,
    workspaceUuid: workspaceUuid,
  );
  _putTrimmedIfPresent(payload, 'scriptUuid', scriptUuid);
  _putPositiveIntIfPresent(payload, 'script_id', scriptNumeric);
  return payload;
}

Map<String, dynamic> _attachScopePayload({
  required String isolationKey,
  String? projectUuid,
  int? projectNumeric,
  String? workspaceUuid,
}) {
  final payload = <String, dynamic>{'isolation_key': isolationKey};
  _putTrimmedIfPresent(payload, 'projectUuid', projectUuid);
  _putPositiveIntIfPresent(payload, 'project_id', projectNumeric);
  _putTrimmedIfPresent(payload, 'workspaceUuid', workspaceUuid);
  return payload;
}

Map<String, dynamic> _workspaceMessage(
  String type,
  Map<String, dynamic> payload,
) {
  return <String, dynamic>{
    'type': type,
    'schema_version': 1,
    'payload': payload,
  };
}

Map<String, dynamic> _agentRunMessage(String prompt) {
  return _workspaceMessage('harness.agent.run', <String, dynamic>{
    'content': prompt,
    'max_tool_rounds': 12,
  });
}

Map<String, dynamic> _toolInvokeMessage(
  String toolName,
  Map<String, dynamic> arguments,
) {
  return _workspaceMessage('harness.tool.invoke', <String, dynamic>{
    'name': toolName,
    'arguments': arguments,
  });
}

Map<String, dynamic> _scriptAttachMessage({
  required String isolationKey,
  String? projectUuid,
  int? projectNumeric,
  String? workspaceUuid,
}) {
  return _workspaceMessage(
    'agent.script.attach',
    _scriptAttachPayload(
      isolationKey: isolationKey,
      projectUuid: projectUuid,
      projectNumeric: projectNumeric,
      workspaceUuid: workspaceUuid,
    ),
  );
}

Map<String, dynamic> _productionAttachMessage({
  required String isolationKey,
  String? projectUuid,
  int? projectNumeric,
  String? scriptUuid,
  int? scriptNumeric,
  String? workspaceUuid,
}) {
  return _workspaceMessage(
    'agent.production.attach',
    _productionAttachPayload(
      isolationKey: isolationKey,
      projectUuid: projectUuid,
      projectNumeric: projectNumeric,
      scriptUuid: scriptUuid,
      scriptNumeric: scriptNumeric,
      workspaceUuid: workspaceUuid,
    ),
  );
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
  final argumentNovelId = toPositiveIntValue(lastToolArguments?['novelId']);
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
    final novelId = toPositiveIntValue(
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
