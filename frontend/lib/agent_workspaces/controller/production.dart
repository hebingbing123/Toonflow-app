// ignore_for_file: invalid_use_of_protected_member

part of '../../../home_page.dart';

extension _HomePageAgentWorkspacesProductionRunController on _HomePageState {
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
