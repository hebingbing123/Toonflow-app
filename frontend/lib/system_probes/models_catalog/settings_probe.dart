part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogSettingsProbe on _HomePageState {
  Future<Map<String, int>> _runModelsCatalogSettingsAndAssetsProbes(
    String token,
  ) async {
    final statuses = <String, int>{};

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

    final scriptAgentGetPlan = await postScriptAgentGetPlanDataV1(
      token,
      projectId: 1,
    );
    _expectProbeStatus(
      label: 'POST script-agent/get-plan-data',
      status: scriptAgentGetPlan,
      accepted: const [200, 404, 503],
    );
    statuses['script-agent/get-plan'] = scriptAgentGetPlan;

    final generate = await postAssetsGenerateGenerateV1(
      token,
      projectId: 1,
      assetNumericId: 1,
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

    final deployModel = await postSettingsAgentDeployModelV1(
      token,
      id: 1,
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

    await _runSettingsVendorAndCredentialProbes(
      token: token,
      statuses: statuses,
      vendorId: vendorAdd.body?.vendorId ?? 'probe-vendor',
      credentialVendorId: vendorAdd.body?.vendorId ?? 'probe-vendor-credential',
    );

    final scriptAgentSetPlan = await postScriptAgentSetPlanDataV1(
      token,
      projectId: 1,
    );
    _expectProbeStatus(
      label: 'POST script-agent/set-plan-data',
      status: scriptAgentSetPlan,
      accepted: const [200, 404, 503],
    );
    statuses['script-agent/set'] = scriptAgentSetPlan;

    final scriptAgentUpdate = await postScriptAgentUpdateDataV1(token, id: 1);
    _expectProbeStatus(
      label: 'POST script-agent/update-data',
      status: scriptAgentUpdate,
      accepted: const [200, 404, 503],
    );
    statuses['script-agent/upd'] = scriptAgentUpdate;

    await _runSettingsAssetGenerateProbes(token: token, statuses: statuses);

    return statuses;
  }

  Future<({int status, VendorMutationResponseV1? body})> _vendorMutationProbe(
    Future<VendorMutationResponseV1> Function() run,
  ) async {
    try {
      final body = await run();
      return (status: 200, body: body);
    } on RustApiException catch (e) {
      return (status: e.statusCode ?? -1, body: null);
    }
  }

  Future<({int status, VendorCredentialResponseV1? body})>
  _vendorCredentialProbe(
    Future<VendorCredentialResponseV1> Function() run,
  ) async {
    try {
      final body = await run();
      return (status: 200, body: body);
    } on RustApiException catch (e) {
      return (status: e.statusCode ?? -1, body: null);
    }
  }

  void _expectProbeStatus({
    required String label,
    required int status,
    required List<int> accepted,
  }) {
    if (accepted.contains(status)) return;
    final expected = accepted.join('/');
    throw StateError('$label expected $expected, got $status');
  }
}
