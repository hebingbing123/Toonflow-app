import '../rust_api.dart';
import 'input_controller.dart';
import 'operation_controller.dart';
import 'runtime_output_controller.dart';

typedef WorkspaceWritebackAccessTokenProvider = String? Function();
typedef WorkspaceWritebackErrorSink = void Function(String? error);
typedef WorkspaceWritebackFetchProjects =
    Future<List<ProjectRow>> Function(String token, int projectNumericId);
typedef WorkspaceWritebackUpdateScript =
    Future<ScriptRow> Function(
      String token,
      String projectId,
      int scriptNumericId,
      Map<String, dynamic> body,
    );
typedef WorkspaceWritebackSetPlanData =
    Future<int> Function(
      String token, {
      required int projectId,
      String storySkeleton,
      String adaptationStrategy,
      List<Map<String, dynamic>> script,
    });
typedef WorkspaceWritebackUpdatePlanData =
    Future<int> Function(
      String token, {
      required int id,
      String storySkeleton,
      String adaptationStrategy,
      List<Map<String, dynamic>> script,
    });
typedef WorkspaceWritebackFetchFlow =
    Future<Map<String, dynamic>> Function(
      String token, {
      required int projectId,
      required int episodesId,
    });
typedef WorkspaceWritebackSaveFlow =
    Future<int> Function(
      String token, {
      required int projectId,
      required int episodesId,
      Map<String, dynamic> data,
    });

class WorkspaceWritebackController {
  WorkspaceWritebackController({
    required WorkspaceInputController inputController,
    required WorkspaceOutputController outputController,
    required WorkspaceOperationController operationController,
    required WorkspaceWritebackAccessTokenProvider accessTokenProvider,
    required WorkspaceWritebackErrorSink onErrorChanged,
    WorkspaceWritebackFetchProjects fetchProjects = postGeneralGetSingleProject,
    WorkspaceWritebackUpdateScript updateScript =
        updateScriptByProjectAndNumericId,
    WorkspaceWritebackSetPlanData setPlanData = postScriptAgentSetPlanDataV1,
    WorkspaceWritebackUpdatePlanData updatePlanData =
        postScriptAgentUpdateDataV1,
    WorkspaceWritebackFetchFlow fetchProductionFlow = fetchProductionFlowDataV1,
    WorkspaceWritebackSaveFlow saveProductionFlow =
        postProductionSaveFlowDataV1,
  }) : _inputController = inputController,
       _outputController = outputController,
       _operationController = operationController,
       _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _fetchProjects = fetchProjects,
       _updateScript = updateScript,
       _setPlanData = setPlanData,
       _updatePlanData = updatePlanData,
       _fetchProductionFlow = fetchProductionFlow,
       _saveProductionFlow = saveProductionFlow;

  final WorkspaceInputController _inputController;
  final WorkspaceOutputController _outputController;
  final WorkspaceOperationController _operationController;
  final WorkspaceWritebackAccessTokenProvider _accessTokenProvider;
  final WorkspaceWritebackErrorSink _onErrorChanged;
  final WorkspaceWritebackFetchProjects _fetchProjects;
  final WorkspaceWritebackUpdateScript _updateScript;
  final WorkspaceWritebackSetPlanData _setPlanData;
  final WorkspaceWritebackUpdatePlanData _updatePlanData;
  final WorkspaceWritebackFetchFlow _fetchProductionFlow;
  final WorkspaceWritebackSaveFlow _saveProductionFlow;

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

  Future<void> writeBackScriptWorkspaceResult() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final projectNumericId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final toolCandidate = _outputController.scriptWritebackCandidate?.trim();
    final assistantText = _outputController.assistantText.trim();
    final useToolCandidate = toolCandidate != null && toolCandidate.isNotEmpty;
    final content = useToolCandidate ? toolCandidate : assistantText;
    final source = useToolCandidate
        ? (_outputController.scriptWritebackSource ?? 'tool:get_script_content')
        : 'assistant stream';
    if (projectNumericId == null || scriptId == null || content.isEmpty) {
      _onErrorChanged('project_id/script_id 与可回写结果必须有效');
      return;
    }

    _beginWriteback(WorkspaceOperation.scriptResultWriteback);
    try {
      final projects = await _fetchProjects(token, projectNumericId);
      if (projects.isEmpty) {
        _onErrorChanged('未找到项目');
        return;
      }
      final updated = await _updateScript(
        token,
        projects.first.id,
        scriptId,
        <String, dynamic>{'content': content},
      );
      final updatedLen = updated.content?.length ?? 0;
      _outputController.setWritebackLine(
        '写回成功：script ${updated.numericId} 已更新，source=$source，content 长度 $updatedLen。',
      );
    } catch (error) {
      _onErrorChanged(error.toString());
    } finally {
      _operationController.setLoading(
        WorkspaceOperation.scriptResultWriteback,
        false,
      );
    }
  }

  Future<void> writeBackScriptPlanWorkspaceResult() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final projectId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final candidate = _outputController.scriptPlanWritebackCandidate;
    if (projectId == null || candidate == null) {
      _onErrorChanged('project_id 与 planData 回写源必须有效');
      return;
    }

    final payload = candidate['data'];
    if (payload is! Map<String, dynamic>) {
      _onErrorChanged('planData 结果缺少 data 字段');
      return;
    }

    final storySkeleton = (payload['storySkeleton'] as String?)?.trim() ?? '';
    final adaptationStrategy =
        (payload['adaptationStrategy'] as String?)?.trim() ?? '';
    final scriptRaw = payload['script'];
    final script = scriptRaw is List
        ? scriptRaw.whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];

    _beginWriteback(WorkspaceOperation.scriptPlanResultWriteback);
    try {
      final status = await _setPlanData(
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
      _outputController.setWritebackLine(
        '写回成功：script-agent planData 已更新（project=$projectId，script_rows=${script.length}）。',
      );
    } catch (error) {
      _onErrorChanged(error.toString());
    } finally {
      _operationController.setLoading(
        WorkspaceOperation.scriptPlanResultWriteback,
        false,
      );
    }
  }

  Future<void> writeBackScriptPlanViaUpdateData() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final planRowId = _outputController.scriptPlanRowId;
    final candidate = _outputController.scriptPlanWritebackCandidate;
    if (planRowId == null || candidate == null) {
      _onErrorChanged('需要 planId 与 planData：请先拉取 get_planData（含 plan 行 id）');
      return;
    }

    final payload = candidate['data'];
    if (payload is! Map<String, dynamic>) {
      _onErrorChanged('planData 结果缺少 data 字段');
      return;
    }

    final storySkeleton = (payload['storySkeleton'] as String?)?.trim() ?? '';
    final adaptationStrategy =
        (payload['adaptationStrategy'] as String?)?.trim() ?? '';
    final scriptRows = _normalizeScriptPlanRows(payload['script']);

    _beginWriteback(WorkspaceOperation.scriptPlanResultWriteback);
    try {
      final status = await _updatePlanData(
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
      _outputController.setWritebackLine(
        '写回成功：script-agent update-data（plan_row_id=$planRowId，script_rows=${scriptRows.length}）。',
      );
    } catch (error) {
      _onErrorChanged(error.toString());
    } finally {
      _operationController.setLoading(
        WorkspaceOperation.scriptPlanResultWriteback,
        false,
      );
    }
  }

  Future<void> writeBackProductionFlowResult() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final projectId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final flowKey = _inputController.productionFlowKeyController.text.trim();
    final toolName = _outputController.lastToolName;
    final result = _outputController.lastToolResultData;
    if (projectId == null ||
        scriptId == null ||
        flowKey.isEmpty ||
        result == null) {
      _onErrorChanged('需先执行工具并拿到结果后再回写');
      return;
    }
    if (toolName == null) {
      _onErrorChanged('缺少工具来源，无法安全回写');
      return;
    }

    Object? payloadForWriteback = result;
    var writebackSource = toolName;
    if (toolName != 'get_flowData' &&
        _coreProductionFlowKeys.contains(flowKey)) {
      final refreshableKey = _toolRefreshableCoreFlowKey[toolName];
      if (refreshableKey == flowKey) {
        try {
          final latestFlow = await _fetchProductionFlow(
            token,
            projectId: projectId,
            episodesId: scriptId,
          );
          payloadForWriteback = latestFlow[flowKey];
          writebackSource = '$toolName -> refreshed flow[$flowKey]';
        } catch (error) {
          _onErrorChanged(error.toString());
          return;
        }
      } else {
        _onErrorChanged(
          '该工具结果不能直接覆盖核心 flow[$flowKey]，请改用扩展 key（如 workspaceResult）或先 get_flowData',
        );
        return;
      }
    }

    if (payloadForWriteback == null) {
      _onErrorChanged('回写数据为空，请先刷新对应 flow key 后重试');
      return;
    }

    _beginWriteback(WorkspaceOperation.productionResultWriteback);
    try {
      final fullFlow = await _fetchProductionFlow(
        token,
        projectId: projectId,
        episodesId: scriptId,
      );
      final merged = Map<String, dynamic>.from(fullFlow);
      merged[flowKey] = payloadForWriteback;
      final status = await _saveProductionFlow(
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
      _outputController.setWritebackLine(
        '回写成功：flow[$flowKey] 已保存到 project $projectId / script $scriptId（source=$writebackSource）。',
      );
    } catch (error) {
      _onErrorChanged(error.toString());
    } finally {
      _operationController.setLoading(
        WorkspaceOperation.productionResultWriteback,
        false,
      );
    }
  }

  void _beginWriteback(WorkspaceOperation operation) {
    _onErrorChanged(null);
    _operationController.setLoading(operation, true);
    _outputController.clearWritebackLine();
  }

  int? _parsePositiveInt(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  List<Map<String, dynamic>> _normalizeScriptPlanRows(Object? scriptRaw) {
    final rows = <Map<String, dynamic>>[];
    if (scriptRaw is! List) {
      return rows;
    }
    for (final item in scriptRaw.whereType<Map<String, dynamic>>()) {
      final rawId = item['numeric_id'] ?? item['id'];
      int? scriptId;
      if (rawId is int) {
        scriptId = rawId;
      } else if (rawId is num) {
        scriptId = rawId.toInt();
      }
      final content = item['content'];
      if (scriptId != null && content is String) {
        rows.add(<String, dynamic>{'id': scriptId, 'content': content});
      }
    }
    return rows;
  }
}
