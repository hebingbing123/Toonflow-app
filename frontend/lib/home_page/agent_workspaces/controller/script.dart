part of '../../../home_page.dart';

extension _HomePageAgentWorkspacesScriptRunController on _HomePageState {
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
}
