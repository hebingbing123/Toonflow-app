part of '../home_page.dart';

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
      assetLegacyId: 1,
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

    final vendorId = vendorAdd.body?.vendorId ?? 'probe-vendor';

    final vendorUpdate = await _vendorMutationProbe(
      () => postSettingsVendorsUpdateV1(
        token,
        id: vendorId,
        displayName: 'Probe Vendor',
        selectedModels: const ['gpt-4o-mini'],
        settings: const {'timeout': '30'},
      ),
    );
    _expectProbeStatus(
      label: 'POST settings/vendors/update',
      status: vendorUpdate.status,
      accepted: const [200, 503],
    );
    statuses['vendors.upd'] = vendorUpdate.status;

    final vendorEnable = await _vendorMutationProbe(
      () => postSettingsVendorsEnableV1(token, id: vendorId, enable: 1),
    );
    _expectProbeStatus(
      label: 'POST settings/vendors/enable',
      status: vendorEnable.status,
      accepted: const [200, 503],
    );
    statuses['vendors.en'] = vendorEnable.status;

    final vendorUpdateCode = await _vendorMutationProbe(
      () => postSettingsVendorsUpdateCodeV1(
        token,
        id: vendorId,
        tsCode: '// probe',
      ),
    );
    _expectProbeStatus(
      label: 'POST settings/vendors/update-code',
      status: vendorUpdateCode.status,
      accepted: const [200, 503],
    );
    statuses['vendors.code'] = vendorUpdateCode.status;

    final vendorFromLink = await _vendorMutationProbe(
      () => postSettingsVendorsCodeFromLinkV1(
        token,
        link: 'https://example.com/a.ts',
      ),
    );
    _expectProbeStatus(
      label: 'POST settings/vendors/code-from-link',
      status: vendorFromLink.status,
      accepted: const [200, 503],
    );
    statuses['vendors.link'] = vendorFromLink.status;

    final credentialVendorId =
        vendorAdd.body?.vendorId ?? 'probe-vendor-credential';
    final credentialStore = await _vendorCredentialProbe(
      () => postSettingsVendorCredentialV1(
        token,
        vendorId: credentialVendorId,
        apiKey: 'sk-probe-1234',
        apiSecret: 'probe-secret',
        apiToken: 'probe-token',
      ),
    );
    _expectProbeStatus(
      label: 'POST settings/vendors/credential',
      status: credentialStore.status,
      accepted: const [200, 501, 503],
    );
    statuses['vendors.cred.store'] = credentialStore.status;

    final credentialGet = await _vendorCredentialProbe(
      () => getSettingsVendorCredentialV1(token, vendorId: credentialVendorId),
    );
    _expectProbeStatus(
      label: 'GET settings/vendors/credential/{vendorId}',
      status: credentialGet.status,
      accepted: const [200, 404, 503],
    );
    statuses['vendors.cred.get'] = credentialGet.status;

    final credentialDelete = await _vendorMutationProbe(
      () =>
          deleteSettingsVendorCredentialV1(token, vendorId: credentialVendorId),
    );
    _expectProbeStatus(
      label: 'DELETE settings/vendors/credential/{vendorId}',
      status: credentialDelete.status,
      accepted: const [200, 404, 503],
    );
    statuses['vendors.cred.del'] = credentialDelete.status;

    final credentialGetAfterDelete = await _vendorCredentialProbe(
      () => getSettingsVendorCredentialV1(token, vendorId: credentialVendorId),
    );
    _expectProbeStatus(
      label: 'GET settings/vendors/credential/{vendorId} after delete',
      status: credentialGetAfterDelete.status,
      accepted: const [404, 503],
    );
    statuses['vendors.cred.get404'] = credentialGetAfterDelete.status;

    final vendorDelete = await _vendorMutationProbe(
      () => postSettingsVendorsDeleteV1(token, id: vendorId),
    );
    _expectProbeStatus(
      label: 'POST settings/vendors/delete',
      status: vendorDelete.status,
      accepted: const [200, 404, 503],
    );
    statuses['vendors.del'] = vendorDelete.status;

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

    final polish = await postAssetsGeneratePolishPromptV1(
      token,
      assetsId: 1,
      projectId: 1,
      type: 'role',
      name: 'n',
      describe: 'd',
    );
    _expectProbeStatus(
      label: 'POST assets-generate/polish-prompt',
      status: polish,
      accepted: const [200, 404, 429, 503],
    );
    statuses['polish'] = polish;

    final batchGenerate = await postAssetsGenerateBatchGenerateV1(
      token,
      projectId: 1,
      model: '1:x',
      resolution: '1024x1024',
      items: const [
        {'id': 1, 'type': 'role', 'name': 'n', 'prompt': 'p'},
      ],
    );
    _expectProbeStatus(
      label: 'POST assets-generate/batch-generate',
      status: batchGenerate,
      accepted: const [200, 404, 429, 503],
    );
    statuses['batch'] = batchGenerate;

    final batchPolish = await postAssetsGenerateBatchPolishV1(
      token,
      projectId: 1,
      items: const [
        {'assetsId': 1, 'type': 'role', 'name': 'n', 'describe': 'd'},
      ],
    );
    _expectProbeStatus(
      label: 'POST assets-generate/batch-polish',
      status: batchPolish,
      accepted: const [200, 404, 429, 503],
    );
    statuses['batch-polish'] = batchPolish;

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
