import '../rust_api.dart';
import 'input_controller.dart';
import 'operation_controller.dart';
import 'runtime_output_controller.dart';

part 'writeback_controller_helpers.dart';

typedef WorkspaceWritebackAccessTokenProvider = String? Function();
typedef WorkspaceWritebackErrorSink = void Function(String? error);
typedef WorkspaceWritebackFetchProjects =
    Future<List<ProjectRow>> Function(String token, int projectNumericId);
typedef WorkspaceWritebackFetchAllProjects =
    Future<List<ProjectRow>> Function(String token);
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
    WorkspaceWritebackFetchAllProjects fetchAllProjects = fetchProjects,
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
       _fetchAllProjects = fetchAllProjects,
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
  final WorkspaceWritebackFetchAllProjects _fetchAllProjects;
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
    final loc = rustApiLookupL10nFromPlatform();
    final projectUuid = _trimmedNonEmpty(
      _inputController.projectUuidController.text,
    );
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
    if ((projectUuid == null && projectNumericId == null) ||
        scriptId == null ||
        content.isEmpty) {
      _onErrorChanged(loc.agentWorkspaceWritebackScriptInputsInvalid);
      return;
    }

    _beginWriteback(WorkspaceOperation.scriptResultWriteback);
    try {
      final resolvedProjectUuid =
          projectUuid ??
          await _resolveProjectUuidFromNumericId(token, projectNumericId!);
      if (resolvedProjectUuid == null || resolvedProjectUuid.isEmpty) {
        _onErrorChanged(loc.agentWorkspaceWritebackProjectNotFound);
        return;
      }
      final updated = await _updateScript(
        token,
        resolvedProjectUuid,
        scriptId,
        <String, dynamic>{'content': content},
      );
      final updatedLen = updated.content?.length ?? 0;
      _outputController.setWritebackLine(
        loc.agentWorkspaceWritebackScriptSuccess(
          updated.numericId,
          source,
          updatedLen,
        ),
      );
    } catch (error) {
      _onErrorChanged(
        describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error),
      );
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
    final loc = rustApiLookupL10nFromPlatform();
    final projectUuid = _trimmedNonEmpty(
      _inputController.projectUuidController.text,
    );
    final projectNumericId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final candidate = _outputController.scriptPlanWritebackCandidate;
    if ((projectNumericId == null && projectUuid == null) ||
        candidate == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackPlanInputsInvalid);
      return;
    }

    final payload = _extractScriptPlanWritebackPayload(candidate);
    if (payload == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackPlanDataMissingData);
      return;
    }
    final rawScript = payload.rawScript;
    final script = rawScript is List
        ? rawScript.whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];

    _beginWriteback(WorkspaceOperation.scriptPlanResultWriteback);
    try {
      final projectId = await _resolveProjectNumericId(
        token,
        projectNumericId: projectNumericId,
        projectUuid: projectUuid,
      );
      if (projectId == null) {
        _onErrorChanged(loc.agentWorkspaceWritebackProjectNotFound);
        return;
      }
      final status = await _setPlanData(
        token,
        projectId: projectId,
        storySkeleton: payload.storySkeleton,
        adaptationStrategy: payload.adaptationStrategy,
        script: script,
      );
      if (status != 200) {
        throw RustApiException(
          'set-plan-data failed with status $status',
          statusCode: status,
        );
      }
      _outputController.setWritebackLine(
        loc.agentWorkspaceWritebackPlanDataSetSuccess(projectId, script.length),
      );
    } catch (error) {
      _onErrorChanged(
        describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error),
      );
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
    final loc = rustApiLookupL10nFromPlatform();
    final planRowId = _outputController.scriptPlanRowId;
    final candidate = _outputController.scriptPlanWritebackCandidate;
    if (planRowId == null || candidate == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackNeedPlanRowAndPlanData);
      return;
    }

    final payload = _extractScriptPlanWritebackPayload(candidate);
    if (payload == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackPlanDataMissingData);
      return;
    }
    final scriptRows = _normalizeScriptPlanRows(payload.rawScript);

    _beginWriteback(WorkspaceOperation.scriptPlanResultWriteback);
    try {
      final status = await _updatePlanData(
        token,
        id: planRowId,
        storySkeleton: payload.storySkeleton,
        adaptationStrategy: payload.adaptationStrategy,
        script: scriptRows,
      );
      if (status != 200) {
        throw RustApiException(
          'update-data failed with status $status',
          statusCode: status,
        );
      }
      _outputController.setWritebackLine(
        loc.agentWorkspaceWritebackPlanDataUpdateSuccess(
          planRowId,
          scriptRows.length,
        ),
      );
    } catch (error) {
      _onErrorChanged(
        describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error),
      );
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
    final loc = rustApiLookupL10nFromPlatform();
    final projectUuid = _trimmedNonEmpty(
      _inputController.projectUuidController.text,
    );
    final projectNumericId = _parsePositiveInt(
      _inputController.projectIdController.text,
    );
    final scriptId = _parsePositiveInt(
      _inputController.scriptIdController.text,
    );
    final flowKey = _inputController.productionFlowKeyController.text.trim();
    final toolName = _outputController.lastToolName;
    final result = _outputController.lastToolResultData;
    if ((projectNumericId == null && projectUuid == null) ||
        scriptId == null ||
        flowKey.isEmpty ||
        result == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackNeedToolResultFirst);
      return;
    }
    if (toolName == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackMissingToolSource);
      return;
    }

    final projectId = await _resolveProjectNumericId(
      token,
      projectNumericId: projectNumericId,
      projectUuid: projectUuid,
    );
    if (projectId == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackProjectNotFound);
      return;
    }

    Object? payloadForWriteback = result;
    var writebackSource = toolName;
    if (toolName == 'get_flowData' &&
        _coreProductionFlowKeys.contains(flowKey)) {
      try {
        final latestFlow = await _fetchProductionFlow(
          token,
          projectId: projectId,
          episodesId: scriptId,
        );
        payloadForWriteback = latestFlow[flowKey];
        writebackSource = 'get_flowData -> refreshed full flow[$flowKey]';
      } catch (error) {
        _onErrorChanged(
          describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error),
        );
        return;
      }
    }
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
          _onErrorChanged(
            describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error),
          );
          return;
        }
      } else {
        _onErrorChanged(
          loc.agentWorkspaceWritebackCoreFlowOverwriteBlocked(flowKey),
        );
        return;
      }
    }

    if (payloadForWriteback == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackPayloadEmptyRefreshFlowKey);
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
        loc.agentWorkspaceWritebackFlowSaved(
          flowKey,
          projectId,
          scriptId,
          writebackSource,
        ),
      );
    } catch (error) {
      _onErrorChanged(
        describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error),
      );
    } finally {
      _operationController.setLoading(
        WorkspaceOperation.productionResultWriteback,
        false,
      );
    }
  }

  Future<String?> _resolveProjectUuidFromNumericId(
    String token,
    int projectNumericId,
  ) async {
    final projects = await _fetchProjects(token, projectNumericId);
    if (projects.isEmpty) {
      return null;
    }
    return projects.first.id;
  }

  Future<int?> _resolveProjectNumericId(
    String token, {
    int? projectNumericId,
    String? projectUuid,
  }) async {
    if (projectNumericId != null && projectNumericId > 0) {
      return projectNumericId;
    }
    if (projectUuid == null || projectUuid.isEmpty) {
      return null;
    }
    final projects = await _fetchAllProjects(token);
    for (final project in projects) {
      if (project.id == projectUuid) {
        return project.numericId;
      }
    }
    return null;
  }

  void _beginWriteback(WorkspaceOperation operation) {
    _onErrorChanged(null);
    _operationController.setLoading(operation, true);
    _outputController.clearWritebackLine();
  }
}
