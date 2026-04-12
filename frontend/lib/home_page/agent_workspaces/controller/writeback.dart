// ignore_for_file: invalid_use_of_protected_member

part of '../../../home_page.dart';

extension _HomePageAgentWorkspacesWritebackController on _HomePageState {
  Future<void> _writeBackScriptWorkspaceResult() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projectNumericId = _parsePositiveInt(_agentWorkspaceProjectIdCtrl.text);
    final scriptId = _parsePositiveInt(_agentWorkspaceScriptIdCtrl.text);
    final toolCandidate = _workspaceScriptWritebackCandidate?.trim();
    final assistantText = _workspaceAssistantText.trim();
    final useToolCandidate = toolCandidate != null && toolCandidate.isNotEmpty;
    final content = useToolCandidate ? toolCandidate : assistantText;
    final source = useToolCandidate
        ? (_workspaceScriptWritebackSource ?? 'tool:get_script_content')
        : 'assistant stream';
    if (projectNumericId == null || scriptId == null || content.isEmpty) {
      setState(() => _error = 'project_id/script_id 与可回写结果必须有效');
      return;
    }

    setState(() {
      _loadingScriptResultWriteback = true;
      _workspaceWritebackLine = null;
      _error = null;
    });

    try {
      final projects = await postGeneralGetSingleProject(token, projectNumericId);
      if (projects.isEmpty) {
        if (!mounted) return;
        setState(() => _error = '未找到项目');
        return;
      }
      final projectUuid = projects.first.id;
      final updated = await updateScriptByProjectAndNumericId(
        token,
        projectUuid,
        scriptId,
        <String, dynamic>{'content': content},
      );
      if (!mounted) return;
      setState(() {
        final updatedLen = updated.content?.length ?? 0;
        _workspaceWritebackLine =
            '写回成功：script ${updated.numericId} 已更新，source=$source，content 长度 $updatedLen。';
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
        final rawId = item['numeric_id'] ?? item['id'];
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
        _HomePageAgentWorkspacesControllerConstants._coreProductionFlowKeys
            .contains(flowKey)) {
      final refreshableKey =
          _HomePageAgentWorkspacesControllerConstants._toolRefreshableCoreFlowKey[
              toolName];
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
