// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

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

  Future<void> _writeBackScriptWorkspaceResult() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final toolCandidate = _workspaceScriptWritebackCandidate?.trim();
    final assistantText = _workspaceAssistantText.trim();
    final useToolCandidate = toolCandidate != null && toolCandidate.isNotEmpty;
    final content = useToolCandidate ? toolCandidate : assistantText;
    final source = useToolCandidate
        ? (_workspaceScriptWritebackSource ?? 'tool:get_script_content')
        : 'assistant stream';
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
            '写回成功：script ${updated.legacyId} 已更新，source=$source，content 长度 $updatedLen。';
      });
    } catch (error) {
      _setErrorFromException(error);
    } finally {
      if (mounted) {
        setState(() => _loadingScriptResultWriteback = false);
      }
    }
  }

  Future<void> _writeBackScriptPlanWorkspaceResult() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final candidate = _workspaceScriptPlanWritebackCandidate;
    if (projectId == null || candidate == null) {
      setState(() => _error = 'project_id 与 planData 回写源必须有效');
      return;
    }

    final payload = candidate['data'];
    if (payload is! Map<String, dynamic>) {
      setState(() => _error = 'planData 结果缺少 data 字段');
      return;
    }

    final storySkeleton = (payload['storySkeleton'] as String?)?.trim() ?? '';
    final adaptationStrategy =
        (payload['adaptationStrategy'] as String?)?.trim() ?? '';
    final scriptRaw = payload['script'];
    final script = scriptRaw is List
        ? scriptRaw.whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];

    setState(() {
      _loadingScriptPlanResultWriteback = true;
      _workspaceWritebackLine = null;
      _error = null;
    });

    try {
      final status = await postScriptAgentSetPlanDataV1(
        token,
        projectId: projectId,
        storySkeleton: storySkeleton,
        adaptationStrategy: adaptationStrategy,
        script: script,
      );
      if (status != 200) {
        throw RustApiException(
          'set-plan-data failed with status $status',
          statusCode: status,
        );
      }
      if (!mounted) return;
      setState(() {
        _workspaceWritebackLine =
            '写回成功：script-agent planData 已更新（project=$projectId，script_rows=${script.length}）。';
      });
    } catch (error) {
      _setErrorFromException(error);
    } finally {
      if (mounted) {
        setState(() => _loadingScriptPlanResultWriteback = false);
      }
    }
  }

  /// 对齐旧 `POST /api/scriptAgent/updateData`：按 `app_script_agent_plan.id` 更新 plan JSON（不经由 project 级 set-plan-data）。
  Future<void> _writeBackScriptPlanViaUpdateData() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final planRowId = _workspaceScriptPlanRowId;
    final candidate = _workspaceScriptPlanWritebackCandidate;
    if (planRowId == null || candidate == null) {
      setState(
        () => _error = '需要 planId 与 planData：请先拉取 get_planData（含 plan 行 id）',
      );
      return;
    }

    final payload = candidate['data'];
    if (payload is! Map<String, dynamic>) {
      setState(() => _error = 'planData 结果缺少 data 字段');
      return;
    }

    final storySkeleton = (payload['storySkeleton'] as String?)?.trim() ?? '';
    final adaptationStrategy =
        (payload['adaptationStrategy'] as String?)?.trim() ?? '';
    final scriptRaw = payload['script'];
    final scriptRows = <Map<String, dynamic>>[];
    if (scriptRaw is List) {
      for (final item in scriptRaw.whereType<Map<String, dynamic>>()) {
        final rawId = item['legacy_id'] ?? item['id'];
        int? sid;
        if (rawId is int) {
          sid = rawId;
        } else if (rawId is num) {
          sid = rawId.toInt();
        }
        final content = item['content'];
        if (sid != null && content is String) {
          scriptRows.add(<String, dynamic>{'id': sid, 'content': content});
        }
      }
    }

    setState(() {
      _loadingScriptPlanResultWriteback = true;
      _workspaceWritebackLine = null;
      _error = null;
    });

    try {
      final status = await postScriptAgentUpdateDataV1(
        token,
        id: planRowId,
        storySkeleton: storySkeleton,
        adaptationStrategy: adaptationStrategy,
        script: scriptRows,
      );
      if (status != 200) {
        throw RustApiException(
          'update-data failed with status $status',
          statusCode: status,
        );
      }
      if (!mounted) return;
      setState(() {
        _workspaceWritebackLine =
            '写回成功：script-agent update-data（plan_row_id=$planRowId，script_rows=${scriptRows.length}）。';
      });
    } catch (error) {
      _setErrorFromException(error);
    } finally {
      if (mounted) {
        setState(() => _loadingScriptPlanResultWriteback = false);
      }
    }
  }

  Future<void> _writeBackProductionFlowResult() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final flowKey = _productionFlowKeyCtrl.text.trim();
    final toolName = _workspaceLastToolName;
    final result = _workspaceLastToolResultData;
    if (projectId == null ||
        scriptId == null ||
        flowKey.isEmpty ||
        result == null) {
      setState(() => _error = '需先执行工具并拿到结果后再回写');
      return;
    }

    if (toolName == null) {
      setState(() => _error = '缺少工具来源，无法安全回写');
      return;
    }

    Object? payloadForWriteback = result;
    var writebackSource = toolName;
    if (toolName != 'get_flowData' &&
        _coreProductionFlowKeys.contains(flowKey)) {
      final refreshableKey = _toolRefreshableCoreFlowKey[toolName];
      if (refreshableKey == flowKey) {
        try {
          final latestFlow = await fetchProductionFlowDataV1(
            token,
            projectId: projectId,
            episodesId: scriptId,
          );
          payloadForWriteback = latestFlow[flowKey];
          writebackSource = '$toolName -> refreshed flow[$flowKey]';
        } catch (error) {
          _setErrorFromException(error);
          return;
        }
      } else {
        setState(
          () => _error =
              '该工具结果不能直接覆盖核心 flow[$flowKey]，请改用扩展 key（如 workspaceResult）或先 get_flowData',
        );
        return;
      }
    }

    if (payloadForWriteback == null) {
      setState(() => _error = '回写数据为空，请先刷新对应 flow key 后重试');
      return;
    }

    setState(() {
      _loadingProductionResultWriteback = true;
      _workspaceWritebackLine = null;
      _error = null;
    });

    try {
      final fullFlow = await fetchProductionFlowDataV1(
        token,
        projectId: projectId,
        episodesId: scriptId,
      );
      final merged = Map<String, dynamic>.from(fullFlow);
      merged[flowKey] = payloadForWriteback;
      final status = await postProductionSaveFlowDataV1(
        token,
        projectId: projectId,
        episodesId: scriptId,
        data: merged,
      );
      if (status != 200) {
        throw RustApiException(
          'save-flow-data failed with status $status',
          statusCode: status,
        );
      }
      if (!mounted) return;
      setState(() {
        _workspaceWritebackLine =
            '回写成功：flow[$flowKey] 已保存到 project $projectId / script $scriptId（source=$writebackSource）。';
      });
    } catch (error) {
      _setErrorFromException(error);
    } finally {
      if (mounted) {
        setState(() => _loadingProductionResultWriteback = false);
      }
    }
  }
}
