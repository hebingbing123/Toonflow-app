import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'input_controller.dart';
import 'operation_controller.dart';
import 'runtime_output_controller.dart';
import 'workspace_scope_utils.dart';

part 'writeback_controller_helpers.dart';

typedef WorkspaceWritebackAccessTokenProvider = String? Function();
typedef WorkspaceWritebackErrorSink = void Function(String? error);
typedef WorkspaceWritebackL10nProvider = AppLocalizations? Function();
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
    required WorkspaceWritebackL10nProvider l10nProvider,
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
       _l10nProvider = l10nProvider,
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
  final WorkspaceWritebackL10nProvider _l10nProvider;
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

  AppLocalizations get _l10nResolved =>
      _l10nProvider() ?? lookupAppLocalizations(const Locale('en'));

  bool skipDemoMutations = false;

  bool _blockDemoMutation() {
    if (!skipDemoMutations) {
      return false;
    }
    _onErrorChanged(_l10nResolved.productDemoModeMutationBlocked);
    return true;
  }

  Future<void> writeBackScriptWorkspaceResult() async {
    if (_blockDemoMutation()) {
      return;
    }
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final request = _readScriptWritebackRequest(
      _inputController,
      _outputController,
      loc,
    );
    if (!request.isValid) {
      _onErrorChanged(loc.agentWorkspaceWritebackScriptInputsInvalid);
      return;
    }

    _beginWriteback(WorkspaceOperation.scriptResultWriteback);
    try {
      final resolvedProjectUuid =
          request.projectScope.projectUuid ??
          await _resolveRequiredProjectUuidFromNumericId(
            token,
            request.projectScope.projectNumericId!,
            loc,
          );
      if (resolvedProjectUuid == null) {
        return;
      }
      final updated = await _updateScript(
        token,
        resolvedProjectUuid,
        request.scriptId!,
        <String, dynamic>{'content': request.content},
      );
      final updatedLen = updated.content?.length ?? 0;
      _outputController.setWritebackLine(
        loc.agentWorkspaceWritebackScriptSuccess(
          updated.numericId,
          request.source,
          updatedLen,
        ),
      );
    } catch (error) {
      _onErrorChanged(describeUserVisibleApiError(_l10nResolved, error));
    } finally {
      _operationController.setLoading(
        WorkspaceOperation.scriptResultWriteback,
        false,
      );
    }
  }

  Future<void> writeBackScriptPlanWorkspaceResult() async {
    if (_blockDemoMutation()) {
      return;
    }
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final projectScope = _readProjectScope(_inputController);
    final candidate = _outputController.scriptPlanWritebackCandidate;
    if (!projectScope.hasProjectScope || candidate == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackPlanInputsInvalid);
      return;
    }

    final request = _readScriptPlanWritebackRequest(candidate);
    if (!request.hasPayload) {
      _onErrorChanged(loc.agentWorkspaceWritebackPlanDataMissingData);
      return;
    }
    final payload = request.payload!;

    _beginWriteback(WorkspaceOperation.scriptPlanResultWriteback);
    try {
      final projectId = await _resolveRequiredProjectNumericId(
        token,
        loc,
        projectNumericId: projectScope.projectNumericId,
        projectUuid: projectScope.projectUuid,
      );
      if (projectId == null) {
        return;
      }
      final status = await _setPlanData(
        token,
        projectId: projectId,
        storySkeleton: payload.storySkeleton,
        adaptationStrategy: payload.adaptationStrategy,
        script: request.normalizedScriptRows,
      );
      if (status != 200) {
        throw RustApiException(
          'set-plan-data failed with status $status',
          statusCode: status,
        );
      }
      _outputController.setWritebackLine(
        loc.agentWorkspaceWritebackPlanDataSetSuccess(
          projectId,
          request.normalizedScriptRows.length,
        ),
      );
    } catch (error) {
      _onErrorChanged(describeUserVisibleApiError(_l10nResolved, error));
    } finally {
      _operationController.setLoading(
        WorkspaceOperation.scriptPlanResultWriteback,
        false,
      );
    }
  }

  Future<void> writeBackScriptPlanViaUpdateData() async {
    if (_blockDemoMutation()) {
      return;
    }
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final planRowId = _outputController.scriptPlanRowId;
    final candidate = _outputController.scriptPlanWritebackCandidate;
    if (planRowId == null || candidate == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackNeedPlanRowAndPlanData);
      return;
    }

    final request = _readScriptPlanWritebackRequest(candidate);
    if (!request.hasPayload) {
      _onErrorChanged(loc.agentWorkspaceWritebackPlanDataMissingData);
      return;
    }
    final payload = request.payload!;

    _beginWriteback(WorkspaceOperation.scriptPlanResultWriteback);
    try {
      final status = await _updatePlanData(
        token,
        id: planRowId,
        storySkeleton: payload.storySkeleton,
        adaptationStrategy: payload.adaptationStrategy,
        script: request.normalizedScriptRows,
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
          request.normalizedScriptRows.length,
        ),
      );
    } catch (error) {
      _onErrorChanged(describeUserVisibleApiError(_l10nResolved, error));
    } finally {
      _operationController.setLoading(
        WorkspaceOperation.scriptPlanResultWriteback,
        false,
      );
    }
  }

  Future<void> writeBackProductionFlowResult() async {
    if (_blockDemoMutation()) {
      return;
    }
    final token = _accessTokenProvider();
    if (token == null) return;
    final loc = _l10nResolved;
    final projectScope = _readProjectScope(_inputController);
    final scriptId = parsePositiveInt(_inputController.scriptIdController.text);
    final flowKey = _inputController.productionFlowKeyController.text.trim();
    final toolName = _outputController.lastToolName;
    final result = _outputController.lastToolResultData;
    if (!projectScope.hasProjectScope ||
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

    _beginWriteback(WorkspaceOperation.productionResultWriteback);
    try {
      final projectId = await _resolveRequiredProjectNumericId(
        token,
        loc,
        projectNumericId: projectScope.projectNumericId,
        projectUuid: projectScope.projectUuid,
      );
      if (projectId == null) {
        return;
      }

      final payloadForWriteback = await _resolveProductionFlowWritebackPayload(
        token: token,
        loc: loc,
        projectId: projectId,
        scriptId: scriptId,
        flowKey: flowKey,
        toolName: toolName,
        result: result,
      );
      if (payloadForWriteback == null) {
        return;
      }
      if (payloadForWriteback.data == null) {
        _onErrorChanged(loc.agentWorkspaceWritebackPayloadEmptyRefreshFlowKey);
        return;
      }

      final fullFlow = await _fetchProductionFlow(
        token,
        projectId: projectId,
        episodesId: scriptId,
      );
      final merged = Map<String, dynamic>.from(fullFlow);
      merged[flowKey] = payloadForWriteback.data;
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
          payloadForWriteback.source,
        ),
      );
    } catch (error) {
      _onErrorChanged(describeUserVisibleApiError(_l10nResolved, error));
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

  Future<String?> _resolveRequiredProjectUuidFromNumericId(
    String token,
    int projectNumericId,
    AppLocalizations loc,
  ) async {
    final projectUuid = await _resolveProjectUuidFromNumericId(
      token,
      projectNumericId,
    );
    if (projectUuid == null || projectUuid.isEmpty) {
      _onErrorChanged(loc.agentWorkspaceWritebackProjectNotFound);
      return null;
    }
    return projectUuid;
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

  Future<int?> _resolveRequiredProjectNumericId(
    String token,
    AppLocalizations loc, {
    int? projectNumericId,
    String? projectUuid,
  }) async {
    final resolvedProjectId = await _resolveProjectNumericId(
      token,
      projectNumericId: projectNumericId,
      projectUuid: projectUuid,
    );
    if (resolvedProjectId == null) {
      _onErrorChanged(loc.agentWorkspaceWritebackProjectNotFound);
      return null;
    }
    return resolvedProjectId;
  }

  Future<_ProductionFlowWritebackPayload?>
  _resolveProductionFlowWritebackPayload({
    required String token,
    required AppLocalizations loc,
    required int projectId,
    required int scriptId,
    required String flowKey,
    required String toolName,
    required Object? result,
  }) async {
    final overwriteBlockedMessage = _productionFlowOverwriteBlockedMessage(
      toolName: toolName,
      flowKey: flowKey,
      coreFlowKeys: _coreProductionFlowKeys,
      refreshableCoreFlowKeyByTool: _toolRefreshableCoreFlowKey,
      l10n: loc,
    );
    if (overwriteBlockedMessage != null) {
      _onErrorChanged(overwriteBlockedMessage);
      return null;
    }

    if (!_shouldRefreshProductionFlowPayload(
      toolName: toolName,
      flowKey: flowKey,
      coreFlowKeys: _coreProductionFlowKeys,
      refreshableCoreFlowKeyByTool: _toolRefreshableCoreFlowKey,
    )) {
      return _ProductionFlowWritebackPayload(data: result, source: toolName);
    }

    try {
      final latestFlow = await _fetchProductionFlow(
        token,
        projectId: projectId,
        episodesId: scriptId,
      );
      return _ProductionFlowWritebackPayload(
        data: latestFlow[flowKey],
        source: _productionFlowRefreshSource(
          toolName: toolName,
          flowKey: flowKey,
        ),
      );
    } catch (error) {
      _onErrorChanged(describeUserVisibleApiError(_l10nResolved, error));
      return null;
    }
  }

  void _beginWriteback(WorkspaceOperation operation) {
    _onErrorChanged(null);
    _operationController.setLoading(operation, true);
    _outputController.clearWritebackLine();
  }
}
