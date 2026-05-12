part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogSettingsProbeCore on _HomePageState {
  Future<({int status, VendorMutationResponseV1? body})>
  _runSettingsBaselineProbes({
    required String token,
    required Map<String, int> statuses,
  }) async {
    final scope = await resolveProductionProbeScope(
      token: token,
      projectIdText: _workspaceInputController.projectIdController.text,
      projectUuidText: _workspaceInputController.projectUuidController.text,
      scriptIdText: _workspaceInputController.scriptIdController.text,
      fetchProjects: fetchProjects,
    );
    final resources = await resolveProductionProbeResourceScope(
      token: token,
      scope: scope,
      projectUuidText: _workspaceInputController.projectUuidController.text,
      fetchProjects: fetchProjects,
      fetchAssets: fetchProjectAssetsByProjectId,
      fetchStoryboards: fetchStoryboardsForProjectScript,
    );
    final projectId = scope.projectId;
    final modelTest = await postSettingsVendorModelTestV1(
      token,
      modelName: 'gpt-4o-mini',
      type: 'text',
      id: '1',
    );
    _expectProbeStatus(
      label: 'POST vendors/model-test',
      status: modelTest,
      accepted: const [200, 429, 503],
    );
    statuses['model-test'] = modelTest;

    final scriptAgentGetPlan = projectId == null
        ? 404
        : await postScriptAgentGetPlanDataV1(token, projectId: projectId);
    _expectProbeStatus(
      label: 'POST script-agent/get-plan-data',
      status: scriptAgentGetPlan,
      accepted: const [200, 404, 503],
    );
    statuses['script-agent/get-plan'] = scriptAgentGetPlan;

    final generate = projectId == null
        ? 404
        : await postAssetsGenerateGenerateV1(
            token,
            projectId: projectId,
            assetNumericId: resources.assetId,
            model: '1:gpt-4o-mini',
            resolution: '1024x1024',
            type: 'role',
            name: 'probe',
            prompt: 'probe',
          );
    _expectProbeStatus(
      label: 'POST assets-generate/generate',
      status: generate,
      accepted: const [200, 404, 429, 503],
    );
    statuses['assets-gen'] = generate;

    final vendorAdd = await _vendorMutationProbe(
      () => postSettingsVendorsAddV1(token, tsCode: 'export {}'),
    );
    _expectProbeStatus(
      label: 'POST settings/vendors/add',
      status: vendorAdd.status,
      accepted: const [200, 503],
    );
    statuses['vendors.add'] = vendorAdd.status;

    final deleteAll = await postSettingsDangerDeleteAllDataV1(token);
    _expectProbeStatus(
      label: 'POST settings/danger/delete-all-data',
      status: deleteAll,
      accepted: const [501],
    );
    statuses['danger/delete-all'] = deleteAll;

    final clearDb = await postSettingsDangerClearDatabaseV1(token);
    _expectProbeStatus(
      label: 'POST settings/danger/clear-database',
      status: clearDb,
      accepted: const [501],
    );
    statuses['clear-db'] = clearDb;
    final agentDeployId = await resolveSettingsProbeAgentDeployId(
      token: token,
      fetchAgentDeployList: postAgentDeployListV1,
    );

    final deployModel = await postSettingsAgentDeployModelV1(
      token,
      id: agentDeployId,
      name: '剧本Agent',
      model: 'x',
      modelName: 'y',
      vendorId: null,
      desc: 'z',
    );
    _expectProbeStatus(
      label: 'POST settings/agent-deploy/deploy-model',
      status: deployModel,
      accepted: const [200, 503],
    );
    statuses['deploy-model'] = deployModel;

    final setKey = await postSettingsAgentDeploySetKeyV1(token);
    _expectProbeStatus(
      label: 'POST settings/agent-deploy/set-key',
      status: setKey,
      accepted: const [200],
    );
    statuses['set-key'] = setKey;

    return vendorAdd;
  }

  Future<void> _runSettingsScriptAgentWriteProbes({
    required String token,
    required Map<String, int> statuses,
  }) async {
    final scope = await resolveProductionProbeScope(
      token: token,
      projectIdText: _workspaceInputController.projectIdController.text,
      projectUuidText: _workspaceInputController.projectUuidController.text,
      scriptIdText: _workspaceInputController.scriptIdController.text,
      fetchProjects: fetchProjects,
    );
    final projectId = scope.projectId;
    final scriptId = scope.scriptId;
    final scriptAgentSetPlan = projectId == null
        ? 404
        : await postScriptAgentSetPlanDataV1(
            token,
            projectId: projectId,
          );
    _expectProbeStatus(
      label: 'POST script-agent/set-plan-data',
      status: scriptAgentSetPlan,
      accepted: const [200, 404, 503],
    );
    statuses['script-agent/set'] = scriptAgentSetPlan;

    final scriptAgentUpdate = scriptId == null
        ? 404
        : await postScriptAgentUpdateDataV1(token, id: scriptId);
    _expectProbeStatus(
      label: 'POST script-agent/update-data',
      status: scriptAgentUpdate,
      accepted: const [200, 404, 503],
    );
    statuses['script-agent/upd'] = scriptAgentUpdate;
  }
}
