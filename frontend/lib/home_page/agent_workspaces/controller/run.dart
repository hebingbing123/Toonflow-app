// ignore_for_file: invalid_use_of_protected_member

part of '../../../home_page.dart';

extension _HomePageAgentWorkspacesController on _HomePageState {
  static const Set<String> _coreProductionFlowKeys = <String>{
    'assets',
    'script',
    'scriptPlan',
    'storyboardTable',
    'storyboard',
  };
  static const Map<String, String> _toolRefreshableCoreFlowKey =
      <String, String>{
        'add_deriveAsset': 'assets',
        'del_deriveAsset': 'assets',
        'generate_deriveAsset': 'assets',
        'generate_storyboard': 'storyboard',
        'run_sub_agent_derive_assets': 'assets',
        'run_sub_agent_generate_assets': 'assets',
        'run_sub_agent_storyboard_gen': 'storyboard',
        'run_sub_agent_storyboard_panel': 'storyboard',
        'run_sub_agent_storyboard_table': 'storyboardTable',
        'run_sub_agent_director_plan': 'scriptPlan',
      };

  int? _parsePositiveInt(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  void _resetWorkspaceOutputs() {
    _workspaceAssistantText = '';
    _workspaceLastToolResultLine = null;
    _workspaceLastToolName = null;
    _workspaceLastToolResultData = null;
    _workspaceSuggestedFlowKey = null;
    _workspaceScriptWritebackCandidate = null;
    _workspaceScriptPlanWritebackCandidate = null;
    _workspaceScriptPlanRowId = null;
    _workspaceScriptWritebackSource = null;
    _workspaceWritebackLine = null;
  }

  void _applySuggestedProductionFlowKey() {
    final suggested = _workspaceSuggestedFlowKey?.trim();
    if (suggested == null || suggested.isEmpty) {
      return;
    }
    setState(() => _productionFlowKeyCtrl.text = suggested);
  }

  Future<void> _runScriptWorkspaceAgent() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final prompt = _scriptWorkspacePromptCtrl.text.trim();
    if (projectId == null || prompt.isEmpty) {
      setState(() => _error = 'project_id 与 prompt 必须有效');
      return;
    }

    setState(() {
      _loadingScriptWorkspaceRun = true;
      _wsLog.clear();
      _resetWorkspaceOutputs();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;
    channel.sink.add(
      jsonEncode({
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': {
          'isolation_key': 'flutter-script-workspace',
          'project_id': projectId,
        },
      }),
    );
    channel.sink.add(
      jsonEncode({
        'type': 'harness.agent.run',
        'schema_version': 1,
        'payload': {'content': prompt, 'max_tool_rounds': 12},
      }),
    );
  }

  Future<void> _runProductionWorkspaceAgent() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final prompt = _productionWorkspacePromptCtrl.text.trim();
    if (projectId == null || scriptId == null || prompt.isEmpty) {
      setState(() => _error = 'project_id/script_id/prompt 必须有效');
      return;
    }

    setState(() {
      _loadingProductionWorkspaceRun = true;
      _wsLog.clear();
      _resetWorkspaceOutputs();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;
    channel.sink.add(
      jsonEncode({
        'type': 'agent.production.attach',
        'schema_version': 1,
        'payload': {
          'isolation_key': 'flutter-production-workspace',
          'project_id': projectId,
          'script_id': scriptId,
        },
      }),
    );
    channel.sink.add(
      jsonEncode({
        'type': 'harness.agent.run',
        'schema_version': 1,
        'payload': {'content': prompt, 'max_tool_rounds': 12},
      }),
    );
  }

  Future<void> _probeProductionDomainTool() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final toolName = _productionDomainToolCtrl.text.trim();
    if (projectId == null || scriptId == null || toolName.isEmpty) {
      setState(() => _error = 'project_id/script_id/tool 必须有效');
      return;
    }

    final argsRaw = _productionDomainArgsCtrl.text.trim();
    final Map<String, dynamic> args;
    if (argsRaw.isEmpty) {
      args = <String, dynamic>{};
    } else {
      try {
        final decoded = jsonDecode(argsRaw);
        if (decoded is! Map<String, dynamic>) {
          setState(() => _error = 'production tool arguments 必须是 JSON object');
          return;
        }
        args = decoded;
      } catch (_) {
        setState(() => _error = 'production tool arguments JSON 解析失败');
        return;
      }
    }

    if (toolName == 'get_flowData') {
      final key = _productionFlowKeyCtrl.text.trim();
      if (key.isEmpty) {
        setState(() => _error = 'get_flowData 需要有效 key');
        return;
      }
      args.putIfAbsent('key', () => key);
      args.putIfAbsent('scriptId', () => scriptId);
    }

    setState(() {
      _loadingProductionFlowProbe = true;
      _wsLog.clear();
      _resetWorkspaceOutputs();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;
    channel.sink.add(
      jsonEncode({
        'type': 'agent.production.attach',
        'schema_version': 1,
        'payload': {
          'isolation_key': 'flutter-production-flow-probe',
          'project_id': projectId,
          'script_id': scriptId,
        },
      }),
    );
    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {'name': toolName, 'arguments': args},
      }),
    );
  }

  Future<void> _probeScriptDomainTool(String toolName, String rawArgs) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    if (projectId == null || toolName.trim().isEmpty) {
      setState(() => _error = 'project_id/tool 必须有效');
      return;
    }
    if (toolName == 'get_script_content' && scriptId == null) {
      setState(() => _error = 'get_script_content 需要有效 script_id');
      return;
    }

    final Map<String, dynamic> args;
    final normalizedArgs = rawArgs.trim();
    if (normalizedArgs.isEmpty) {
      args = <String, dynamic>{};
    } else {
      try {
        final decoded = jsonDecode(normalizedArgs);
        if (decoded is! Map<String, dynamic>) {
          setState(() => _error = 'script tool arguments 必须是 JSON object');
          return;
        }
        args = decoded;
      } catch (_) {
        setState(() => _error = 'script tool arguments JSON 解析失败');
        return;
      }
    }
    if (toolName == 'get_script_content' && scriptId != null) {
      args.putIfAbsent('scriptId', () => scriptId);
    }

    setState(() {
      _loadingScriptDomainProbe = true;
      _wsLog.clear();
      _resetWorkspaceOutputs();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;
    channel.sink.add(
      jsonEncode({
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': {
          'isolation_key': 'flutter-script-domain-probe',
          'project_id': projectId,
        },
      }),
    );
    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {'name': toolName, 'arguments': args},
      }),
    );
  }

  Future<void> _runScriptSubAgentTool() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final prompt = _scriptWorkspacePromptCtrl.text.trim();
    final toolName = _scriptSubAgentToolCtrl.text.trim();
    if (projectId == null || prompt.isEmpty || toolName.isEmpty) {
      setState(() => _error = 'project_id/prompt/tool 必须有效');
      return;
    }

    setState(() {
      _loadingScriptSubAgentRun = true;
      _wsLog.clear();
      _resetWorkspaceOutputs();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;
    final arguments = <String, dynamic>{'prompt': prompt, 'scriptId': scriptId}
      ..removeWhere((_, Object? value) => value == null);
    channel.sink.add(
      jsonEncode({
        'type': 'agent.script.attach',
        'schema_version': 1,
        'payload': {
          'isolation_key': 'flutter-script-sub-agent-tool',
          'project_id': projectId,
        },
      }),
    );
    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {'name': toolName, 'arguments': arguments},
      }),
    );
  }

  Future<void> _runProductionSubAgentTool() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final prompt = _productionWorkspacePromptCtrl.text.trim();
    final toolName = _productionSubAgentToolCtrl.text.trim();
    if (projectId == null ||
        scriptId == null ||
        prompt.isEmpty ||
        toolName.isEmpty) {
      setState(() => _error = 'project_id/script_id/prompt/tool 必须有效');
      return;
    }

    setState(() {
      _loadingProductionSubAgentRun = true;
      _wsLog.clear();
      _resetWorkspaceOutputs();
      _error = null;
    });

    final channel = await _openHarnessChannel(token);
    if (channel == null) return;
    channel.sink.add(
      jsonEncode({
        'type': 'agent.production.attach',
        'schema_version': 1,
        'payload': {
          'isolation_key': 'flutter-production-sub-agent-tool',
          'project_id': projectId,
          'script_id': scriptId,
        },
      }),
    );
    channel.sink.add(
      jsonEncode({
        'type': 'harness.tool.invoke',
        'schema_version': 1,
        'payload': {
          'name': toolName,
          'arguments': {'prompt': prompt, 'scriptId': scriptId},
        },
      }),
    );
  }

}
