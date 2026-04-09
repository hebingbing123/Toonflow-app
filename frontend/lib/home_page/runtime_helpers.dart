// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageRuntimeHelpers on _HomePageState {
  Session? get _session =>
      kSupabaseConfigured ? Supabase.instance.client.auth.currentSession : null;

  bool get _wsProbesBusy =>
      _loadingWs ||
      _loadingWsHarness ||
      _loadingWsIsolatedEcho ||
      _loadingWsWasmProbe ||
      _loadingWsHarnessAgent ||
      _loadingWsSkillsRead ||
      _loadingScriptWorkspaceRun ||
      _loadingProductionWorkspaceRun ||
      _loadingProductionFlowProbe ||
      _loadingScriptResultWriteback ||
      _loadingProductionResultWriteback;

  void _appendWsLog(String raw) {
    const maxChars = 12000;
    final line = raw.length > maxChars
        ? '${raw.substring(0, maxChars)}… (+${raw.length - maxChars} chars)'
        : raw;
    final decoded = _tryDecodeWsJson(raw);
    if (!mounted) return;
    setState(() {
      if (decoded != null) {
        _ingestWorkspaceWsEvent(decoded);
      }
      _wsLog.insert(0, line);
      if (_wsLog.length > 16) _wsLog.removeLast();
    });
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
    final type = event['type'];
    if (type is! String || type.isEmpty) {
      return;
    }
    final payload = event['payload'];
    final payloadMap = payload is Map<String, dynamic> ? payload : null;

    if (type == 'harness.agent.started') {
      _workspaceAssistantText = '';
      _workspaceWritebackLine = null;
      return;
    }

    if (type == 'chat.content.updated' && payloadMap != null) {
      final append = payloadMap['append'];
      if (append is String && append.isNotEmpty) {
        _workspaceAssistantText = _trimWorkspaceText(
          '$_workspaceAssistantText$append',
        );
      }
      return;
    }

    if (type == 'harness.tool.result' && payloadMap != null) {
      final name = payloadMap['name'];
      final result = payloadMap['result'];
      if (name is String) {
        _workspaceLastToolName = name;
        _workspaceLastToolResultData = result;
        final encoded = jsonEncode(result);
        final summary = encoded.length > 320
            ? '${encoded.substring(0, 320)}...'
            : encoded;
        _workspaceLastToolResultLine = '$name => $summary';
      }
      return;
    }

    if (type == 'harness.agent.cancelled') {
      _workspaceWritebackLine = '当前运行已取消，可检查日志后决定是否写回。';
    }
  }

  String _trimWorkspaceText(String text) {
    const maxChars = 40000;
    if (text.length <= maxChars) {
      return text;
    }
    return text.substring(text.length - maxChars);
  }

  void _setErrorFromException(Object error) {
    if (!mounted) return;
    setState(() => _error = error.toString());
  }
}
