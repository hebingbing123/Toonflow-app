part of 'writeback_controller.dart';

class _ProjectScopeRef {
  const _ProjectScopeRef({this.projectUuid, this.projectNumericId});

  final String? projectUuid;
  final int? projectNumericId;

  bool get hasProjectScope => projectUuid != null || projectNumericId != null;
}

class _ScriptWritebackRequest {
  const _ScriptWritebackRequest({
    required this.projectScope,
    required this.scriptId,
    required this.content,
    required this.source,
  });

  final _ProjectScopeRef projectScope;
  final int? scriptId;
  final String content;
  final String source;

  bool get isValid =>
      projectScope.hasProjectScope && scriptId != null && content.isNotEmpty;
}

class _ScriptPlanWritebackPayload {
  const _ScriptPlanWritebackPayload({
    required this.storySkeleton,
    required this.adaptationStrategy,
    required this.rawScript,
  });

  final String storySkeleton;
  final String adaptationStrategy;
  final Object? rawScript;
}

class _ScriptPlanWritebackRequest {
  const _ScriptPlanWritebackRequest({
    required this.payload,
    required this.scriptRows,
    required this.normalizedScriptRows,
  });

  final _ScriptPlanWritebackPayload? payload;
  final List<Map<String, dynamic>> scriptRows;
  final List<Map<String, dynamic>> normalizedScriptRows;

  bool get hasPayload => payload != null;
}

class _ProductionFlowWritebackPayload {
  const _ProductionFlowWritebackPayload({this.data, required this.source});

  final Object? data;
  final String source;
}

_ProjectScopeRef _readProjectScope(WorkspaceInputController input) {
  return _ProjectScopeRef(
    projectUuid: trimmedNonEmpty(input.projectUuidController.text),
    projectNumericId: parsePositiveInt(input.projectIdController.text),
  );
}

_ScriptWritebackRequest _readScriptWritebackRequest(
  WorkspaceInputController input,
  WorkspaceOutputController output,
  AppLocalizations l10n,
) {
  final toolCandidate = output.scriptWritebackCandidate?.trim();
  final assistantText = output.assistantText.trim();
  final useToolCandidate = toolCandidate != null && toolCandidate.isNotEmpty;
  return _ScriptWritebackRequest(
    projectScope: _readProjectScope(input),
    scriptId: parsePositiveInt(input.scriptIdController.text),
    content: useToolCandidate ? toolCandidate : assistantText,
    source: useToolCandidate
        ? (output.scriptWritebackSource ??
              l10n.agentWorkspaceScriptWritebackSourceToolGetScriptContent)
        : l10n.agentWorkspaceScriptWritebackSourceAssistant,
  );
}

List<Map<String, dynamic>> _normalizeScriptPlanRows(Object? scriptRaw) {
  final rows = <Map<String, dynamic>>[];
  if (scriptRaw is! List) {
    return rows;
  }
  for (final item in scriptRaw.whereType<Map<String, dynamic>>()) {
    final scriptId = toPositiveIntValue(item['numeric_id'] ?? item['id']);
    final content = item['content'];
    if (scriptId != null && content is String) {
      rows.add(<String, dynamic>{'id': scriptId, 'content': content});
    }
  }
  return rows;
}

_ScriptPlanWritebackPayload? _extractScriptPlanWritebackPayload(
  Map<String, dynamic> candidate,
) {
  final payload = candidate['data'];
  if (payload is! Map<String, dynamic>) return null;
  return _ScriptPlanWritebackPayload(
    storySkeleton: (payload['storySkeleton'] as String?)?.trim() ?? '',
    adaptationStrategy:
        (payload['adaptationStrategy'] as String?)?.trim() ?? '',
    rawScript: payload['script'],
  );
}

_ScriptPlanWritebackRequest _readScriptPlanWritebackRequest(
  Map<String, dynamic> candidate,
) {
  final payload = _extractScriptPlanWritebackPayload(candidate);
  final rawScript = payload?.rawScript;
  final scriptRows = rawScript is List
      ? rawScript.whereType<Map<String, dynamic>>().toList(growable: false)
      : const <Map<String, dynamic>>[];
  return _ScriptPlanWritebackRequest(
    payload: payload,
    scriptRows: scriptRows,
    normalizedScriptRows: _normalizeScriptPlanRows(rawScript),
  );
}

bool _isCoreProductionFlowKey(String flowKey, Set<String> coreFlowKeys) {
  return coreFlowKeys.contains(flowKey);
}

bool _shouldRefreshProductionFlowPayload({
  required String toolName,
  required String flowKey,
  required Set<String> coreFlowKeys,
  required Map<String, String> refreshableCoreFlowKeyByTool,
}) {
  if (!_isCoreProductionFlowKey(flowKey, coreFlowKeys)) {
    return false;
  }
  if (toolName == 'get_flowData') {
    return true;
  }
  return refreshableCoreFlowKeyByTool[toolName] == flowKey;
}

String? _productionFlowOverwriteBlockedMessage({
  required String toolName,
  required String flowKey,
  required Set<String> coreFlowKeys,
  required Map<String, String> refreshableCoreFlowKeyByTool,
  required AppLocalizations l10n,
}) {
  if (!_isCoreProductionFlowKey(flowKey, coreFlowKeys)) {
    return null;
  }
  if (toolName == 'get_flowData' ||
      refreshableCoreFlowKeyByTool[toolName] == flowKey) {
    return null;
  }
  return l10n.agentWorkspaceWritebackCoreFlowOverwriteBlocked(flowKey);
}

String _productionFlowRefreshSource({
  required String toolName,
  required String flowKey,
}) {
  if (toolName == 'get_flowData') {
    return 'get_flowData -> refreshed full flow[$flowKey]';
  }
  return '$toolName -> refreshed flow[$flowKey]';
}
