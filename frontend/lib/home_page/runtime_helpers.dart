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
      _loadingScriptDomainProbe ||
      _loadingProductionFlowProbe ||
      _loadingScriptSubAgentRun ||
      _loadingProductionSubAgentRun ||
      _loadingScriptResultWriteback ||
      _loadingScriptPlanResultWriteback ||
      _loadingProductionResultWriteback;

  void _resetWorkspaceWsOperationFlags() {
    _loadingScriptWorkspaceRun = false;
    _loadingProductionWorkspaceRun = false;
    _loadingScriptDomainProbe = false;
    _loadingProductionFlowProbe = false;
    _loadingScriptSubAgentRun = false;
    _loadingProductionSubAgentRun = false;
  }

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
    final resolution = resolveWorkspaceWsEvent(event);
    if (resolution.clearAllOperations) {
      _resetWsBusyFlags();
      _resetWorkspaceWsOperationFlags();
    } else {
      if (resolution.clearToolOperations) {
        _loadingWsHarness = false;
        _loadingWsIsolatedEcho = false;
        _loadingWsWasmProbe = false;
        _loadingWsSkillsRead = false;
        _loadingScriptDomainProbe = false;
        _loadingProductionFlowProbe = false;
        _loadingScriptSubAgentRun = false;
        _loadingProductionSubAgentRun = false;
      }
      if (resolution.clearAgentOperations) {
        _loadingWs = false;
        _loadingWsHarnessAgent = false;
        _loadingScriptWorkspaceRun = false;
        _loadingProductionWorkspaceRun = false;
      }
    }

    final type = event['type'];
    if (type is! String || type.isEmpty) {
      return;
    }
    final payload = event['payload'];
    final payloadMap = payload is Map<String, dynamic> ? payload : null;

    if (type == 'harness.agent.started') {
      _workspaceAssistantText = '';
      _workspaceScriptWritebackCandidate = null;
      _workspaceScriptPlanWritebackCandidate = null;
      _workspaceScriptPlanRowId = null;
      _workspaceScriptWritebackSource = null;
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
        _workspaceSuggestedFlowKey = _suggestFlowKeyFromToolName(name);
        if (name == 'get_script_content') {
          final content = _extractScriptContentFromToolResult(result);
          if (content != null && content.isNotEmpty) {
            _workspaceScriptWritebackCandidate = _trimWorkspaceText(content);
            _workspaceScriptWritebackSource =
                'tool:get_script_content (${content.length} chars)';
          }
        }
        if (name == 'run_sub_agent_script') {
          final content = _extractSubAgentResultText(result);
          if (content != null && content.isNotEmpty) {
            _workspaceScriptWritebackCandidate = _trimWorkspaceText(content);
            _workspaceScriptWritebackSource =
                'tool:run_sub_agent_script (${content.length} chars)';
          }
        }
        if (name == 'get_planData') {
          _workspaceScriptPlanWritebackCandidate =
              _extractScriptPlanDataFromToolResult(result);
          _workspaceScriptPlanRowId = _extractScriptPlanRowIdFromToolResult(result);
        }
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
      return;
    }
  }

  String _trimWorkspaceText(String text) {
    const maxChars = 40000;
    if (text.length <= maxChars) {
      return text;
    }
    return text.substring(text.length - maxChars);
  }

  String? _extractScriptContentFromToolResult(Object? result) {
    if (result is Map<String, dynamic>) {
      final content = result['content'];
      if (content is String) {
        return content.trim();
      }
    }
    return null;
  }

  Map<String, dynamic>? _extractScriptPlanDataFromToolResult(Object? result) {
    if (result is Map<String, dynamic>) {
      final data = result['data'];
      if (data is Map<String, dynamic>) {
        return result;
      }
    }
    return null;
  }

  int? _extractScriptPlanRowIdFromToolResult(Object? result) {
    if (result is! Map<String, dynamic>) {
      return null;
    }
    final raw = result['planId'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return null;
  }

  String? _extractSubAgentResultText(Object? result) {
    if (result is! Map<String, dynamic>) {
      return null;
    }
    final text = result['result'];
    if (text is String) {
      return text.trim();
    }
    return null;
  }

  String? _suggestFlowKeyFromToolName(String name) {
    switch (name) {
      case 'get_flowData':
        final key = _productionFlowKeyCtrl.text.trim();
        if (key.isNotEmpty) return key;
        return 'workspaceResult';
      case 'add_deriveAsset':
      case 'del_deriveAsset':
      case 'generate_deriveAsset':
      case 'run_sub_agent_derive_assets':
      case 'run_sub_agent_generate_assets':
        return 'assets';
      case 'generate_storyboard':
      case 'run_sub_agent_storyboard_gen':
      case 'run_sub_agent_storyboard_panel':
        return 'storyboard';
      case 'run_sub_agent_storyboard_table':
        return 'storyboardTable';
      case 'run_sub_agent_director_plan':
        return 'scriptPlan';
      default:
        return 'workspaceResult';
    }
  }

  void _setErrorFromException(Object error) {
    if (!mounted) return;
    setState(() => _error = error.toString());
  }
}
