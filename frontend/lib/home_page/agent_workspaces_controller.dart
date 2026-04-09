// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageAgentWorkspacesController on _HomePageState {
  int? _parsePositiveInt(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    return value;
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
      _workspaceAssistantText = '';
      _workspaceLastToolResultLine = null;
      _workspaceWritebackLine = null;
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

    if (mounted) setState(() => _loadingScriptWorkspaceRun = false);
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
      _workspaceAssistantText = '';
      _workspaceLastToolResultLine = null;
      _workspaceWritebackLine = null;
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

    if (mounted) setState(() => _loadingProductionWorkspaceRun = false);
  }

  Future<void> _probeProductionFlowTool() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final key = _productionFlowKeyCtrl.text.trim();
    if (projectId == null || scriptId == null || key.isEmpty) {
      setState(() => _error = 'project_id/script_id/key 必须有效');
      return;
    }

    setState(() {
      _loadingProductionFlowProbe = true;
      _wsLog.clear();
      _workspaceAssistantText = '';
      _workspaceLastToolResultLine = null;
      _workspaceWritebackLine = null;
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
        'payload': {
          'name': 'get_flowData',
          'arguments': {'key': key, 'scriptId': scriptId},
        },
      }),
    );

    if (mounted) setState(() => _loadingProductionFlowProbe = false);
  }

  Future<void> _runScriptSubAgentTool() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final prompt = _scriptWorkspacePromptCtrl.text.trim();
    final toolName = _scriptSubAgentToolCtrl.text.trim();
    if (projectId == null || prompt.isEmpty || toolName.isEmpty) {
      setState(() => _error = 'project_id/prompt/tool 必须有效');
      return;
    }

    setState(() {
      _loadingScriptSubAgentRun = true;
      _wsLog.clear();
      _workspaceAssistantText = '';
      _workspaceLastToolResultLine = null;
      _workspaceWritebackLine = null;
      _error = null;
    });

    try {
      final channel = await _openHarnessChannel(token);
      if (channel == null) return;
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
          'payload': {
            'name': toolName,
            'arguments': {'prompt': prompt},
          },
        }),
      );
    } finally {
      if (mounted) setState(() => _loadingScriptSubAgentRun = false);
    }
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
      _workspaceAssistantText = '';
      _workspaceLastToolResultLine = null;
      _workspaceWritebackLine = null;
      _error = null;
    });

    try {
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
    } finally {
      if (mounted) setState(() => _loadingProductionSubAgentRun = false);
    }
  }

  Future<void> _writeBackScriptWorkspaceResult() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final content = _workspaceAssistantText.trim();
    if (scriptId == null || content.isEmpty) {
      setState(() => _error = 'script_id 与可回写结果必须有效');
      return;
    }

    setState(() {
      _loadingScriptResultWriteback = true;
      _workspaceWritebackLine = null;
      _error = null;
    });

    try {
      final updated = await updateScriptByLegacyId(
        token,
        scriptId,
        <String, dynamic>{'content': content},
      );
      if (!mounted) return;
      setState(() {
        final updatedLen = updated.content?.length ?? 0;
        _workspaceWritebackLine =
            '写回成功：script ${updated.legacyId} 已更新，content 长度 $updatedLen。';
      });
    } catch (error) {
      _setErrorFromException(error);
    } finally {
      if (mounted) {
        setState(() => _loadingScriptResultWriteback = false);
      }
    }
  }
}
