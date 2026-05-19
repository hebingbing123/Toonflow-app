part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogSettingsProbeVendorAssets
    on _HomePageState {
  Future<void> _runSettingsVendorAndCredentialProbes({
    required String token,
    required Map<String, int> statuses,
    required String vendorId,
    required String credentialVendorId,
  }) async {
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
      label: _probeHttpLabel('POST settings/vendors/update'),
      status: vendorUpdate.status,
      accepted: const [200, 503],
    );
    statuses['vendors.upd'] = vendorUpdate.status;

    final vendorEnable = await _vendorMutationProbe(
      () => postSettingsVendorsEnableV1(token, id: vendorId, enable: 1),
    );
    _expectProbeStatus(
      label: _probeHttpLabel('POST settings/vendors/enable'),
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
      label: _probeHttpLabel('POST settings/vendors/update-code'),
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
      label: _probeHttpLabel('POST settings/vendors/code-from-link'),
      status: vendorFromLink.status,
      accepted: const [200, 503],
    );
    statuses['vendors.link'] = vendorFromLink.status;

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
      label: _probeHttpLabel('POST settings/vendors/credential'),
      status: credentialStore.status,
      accepted: const [200, 501, 503],
    );
    statuses['vendors.cred.store'] = credentialStore.status;

    final credentialGet = await _vendorCredentialProbe(
      () => getSettingsVendorCredentialV1(token, vendorId: credentialVendorId),
    );
    _expectProbeStatus(
      label: _probeHttpLabel('GET settings/vendors/credential/{vendorId}'),
      status: credentialGet.status,
      accepted: const [200, 404, 503],
    );
    statuses['vendors.cred.get'] = credentialGet.status;

    final credentialDelete = await _vendorMutationProbe(
      () =>
          deleteSettingsVendorCredentialV1(token, vendorId: credentialVendorId),
    );
    _expectProbeStatus(
      label: _probeHttpLabel('DELETE settings/vendors/credential/{vendorId}'),
      status: credentialDelete.status,
      accepted: const [200, 404, 503],
    );
    statuses['vendors.cred.del'] = credentialDelete.status;

    final credentialGetAfterDelete = await _vendorCredentialProbe(
      () => getSettingsVendorCredentialV1(token, vendorId: credentialVendorId),
    );
    _expectProbeStatus(
      label: _probeHttpLabel('GET settings/vendors/credential/{vendorId} after delete'),
      status: credentialGetAfterDelete.status,
      accepted: const [404, 503],
    );
    statuses['vendors.cred.get404'] = credentialGetAfterDelete.status;

    final vendorDelete = await _vendorMutationProbe(
      () => postSettingsVendorsDeleteV1(token, id: vendorId),
    );
    _expectProbeStatus(
      label: _probeHttpLabel('POST settings/vendors/delete'),
      status: vendorDelete.status,
      accepted: const [200, 404, 503],
    );
    statuses['vendors.del'] = vendorDelete.status;
  }

  Future<void> _runSettingsAssetGenerateProbes({
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
    final polish = projectId == null
        ? 404
        : await postAssetsGeneratePolishPromptV1(
            token,
            assetsId: resources.assetId,
            projectId: projectId,
            type: 'role',
            name: 'n',
            describe: 'd',
          );
    _expectProbeStatus(
      label: _probeHttpLabel('POST assets-generate/polish-prompt'),
      status: polish,
      accepted: const [200, 404, 429, 503],
    );
    statuses['polish'] = polish;

    final batchGenerate = projectId == null
        ? 404
        : await postAssetsGenerateBatchGenerateV1(
            token,
            projectId: projectId,
            model: '1:x',
            resolution: '1024x1024',
            items: [
              {
                'id': resources.assetId,
                'type': 'role',
                'name': 'n',
                'prompt': 'p',
              },
            ],
          );
    _expectProbeStatus(
      label: _probeHttpLabel('POST assets-generate/batch-generate'),
      status: batchGenerate,
      accepted: const [200, 404, 429, 503],
    );
    statuses['batch'] = batchGenerate;

    final batchPolish = projectId == null
        ? 404
        : await postAssetsGenerateBatchPolishV1(
            token,
            projectId: projectId,
            items: [
              {
                'assetsId': resources.assetId,
                'type': 'role',
                'name': 'n',
                'describe': 'd',
              },
            ],
          );
    _expectProbeStatus(
      label: _probeHttpLabel('POST assets-generate/batch-polish'),
      status: batchPolish,
      accepted: const [200, 404, 429, 503],
    );
    statuses['batch-polish'] = batchPolish;

    final cancelGenerate = await postAssetsGenerateCancelGenerateV1(
      token,
      numericImageId: 1,
    );
    _expectProbeStatus(
      label: _probeHttpLabel('POST assets-generate/cancel-generate'),
      status: cancelGenerate,
      accepted: const [200, 503],
    );
    statuses['cancel-generate'] = cancelGenerate;
  }
}
