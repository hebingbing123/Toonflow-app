// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageRuntimeHelpers on _HomePageState {
  Session? get _session =>
      kSupabaseConfigured ? Supabase.instance.client.auth.currentSession : null;

  bool get _wsProbesBusy =>
      _skillsHarnessController.wsProbesBusy ||
      _workspaceOperationController.hasPendingWork;

  void _resetWorkspaceWsOperationFlags() {
    _workspaceOperationController.resetWsOperations();
  }

  void _handleHarnessWsMessage(String raw) {
    final decoded = _tryDecodeWsJson(raw);
    if (decoded != null) {
      _ingestWorkspaceWsEvent(decoded);
    }
  }

  Map<String, dynamic>? _tryDecodeWsJson(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  void _ingestWorkspaceWsEvent(Map<String, dynamic> event) {
    final resolution = resolveWorkspaceWsEvent(event);
    if (resolution.clearAllOperations) {
      _skillsHarnessController.resetWsBusyFlags();
      _workspaceOperationController.resetWsOperations();
    } else {
      if (resolution.clearToolOperations) {
        _skillsHarnessController.clearToolProbeFlags();
        _workspaceOperationController.clearToolOperations();
      }
      if (resolution.clearAgentOperations) {
        _skillsHarnessController.clearAgentProbeFlags();
        _workspaceOperationController.clearAgentOperations();
      }
    }

    final type = event['type'];
    if (type is! String || type.isEmpty) {
      return;
    }
    final payload = event['payload'];
    final payloadMap = payload is Map<String, dynamic> ? payload : null;

    if (type == 'harness.agent.started') {
      _workspaceOutputController.markAgentStarted();
      return;
    }

    if (type == 'chat.content.updated' && payloadMap != null) {
      final append = payloadMap['append'];
      if (append is String && append.isNotEmpty) {
        _workspaceOutputController.appendAssistantText(append);
      }
      return;
    }

    if (type == 'harness.tool.result' && payloadMap != null) {
      final name = payloadMap['name'];
      final result = payloadMap['result'];
      if (name is String) {
        _workspaceOutputController.recordToolResult(
          name,
          result,
          currentFlowKey:
              _workspaceInputController.productionFlowKeyController.text,
        );
      }
      return;
    }

    if (type == 'harness.agent.cancelled') {
      _workspaceOutputController.markCancelled();
      return;
    }
  }

  void _setErrorFromException(Object error) {
    if (!mounted) return;
    setState(() => _error = error.toString());
  }
}
