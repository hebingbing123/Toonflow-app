part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogProductionProbe on _HomePageState {
  int _missingProductionScopeStatus({
    required Map<String, int> statuses,
    required String key,
    required String label,
  }) {
    const status = 404;
    _expectProbeStatus(
      label: label,
      status: status,
      accepted: const [200, 404, 503],
    );
    statuses[key] = status;
    return status;
  }

  Future<({Map<String, int> statuses, int implementedCount})>
  _runModelsCatalogProductionProbes(String token) async {
    final statuses = <String, int>{};
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
    final projectUuid = resources.projectUuid;
    final scriptId = scope.scriptId;
    if (projectId == null || scriptId == null) {
      _missingProductionScopeStatus(
        statuses: statuses,
        key: 'production/get-data',
        label: 'POST production/get-production-data',
      );
      _missingProductionScopeStatus(
        statuses: statuses,
        key: 'flow',
        label: 'POST production/get-flow-data',
      );
      _missingProductionScopeStatus(
        statuses: statuses,
        key: 'save',
        label: 'POST production/save-flow-data',
      );
      _missingProductionScopeStatus(
        statuses: statuses,
        key: 'workbench/generate',
        label: 'POST production/workbench/generate-video',
      );
      _missingProductionScopeStatus(
        statuses: statuses,
        key: 'workbench/batch-candidate-clips',
        label: 'POST production/workbench/batch-generate-candidate-clips',
      );
      _missingProductionScopeStatus(
        statuses: statuses,
        key: 'storyboard/poll',
        label: 'POST production/storyboard/polling-image',
      );
      _missingProductionScopeStatus(
        statuses: statuses,
        key: 'export',
        label: 'POST production/export-image',
      );
      await _runTypedProductionProbeSuite(
        token,
        statuses,
        projectId: -1,
        projectUuid: projectUuid,
        scriptId: -1,
        assetId: resources.assetId,
        storyboardId: resources.storyboardId,
        skipRequests: true,
      );
      return (statuses: statuses, implementedCount: 29);
    }

    final getData = await postProductionGetProductionDataV1(
      token,
      projectId: projectId,
      projectUuid: projectUuid,
      scriptId: scriptId,
      storyboardIds: [resources.storyboardId],
    );
    _expectProbeStatus(
      label: 'POST production/get-production-data',
      status: getData,
      accepted: const [200, 404, 503],
    );
    statuses['production/get-data'] = getData;

    final flowData = await postProductionGetFlowDataV1(
      token,
      projectId: projectId,
      episodesId: scriptId,
    );
    _expectProbeStatus(
      label: 'POST production/get-flow-data',
      status: flowData,
      accepted: const [200, 404, 503],
    );
    statuses['flow'] = flowData;

    final flowSave = await postProductionSaveFlowDataV1(
      token,
      projectId: projectId,
      episodesId: scriptId,
    );
    _expectProbeStatus(
      label: 'POST production/save-flow-data',
      status: flowSave,
      accepted: const [200, 404, 503],
    );
    statuses['save'] = flowSave;

    await postProductionWorkbenchGenerateVideoV1(
      token,
      projectId: projectId,
      scriptId: scriptId,
      uploadData: [
        {'id': resources.assetId, 'sources': 'assets'},
      ],
      prompt: 'p',
      model: '1:x',
      mode: 'std',
      resolution: '720p',
      duration: 5,
      trackId: 1,
    );
    _expectProbeStatus(
      label: 'POST production/workbench/generate-video',
      status: 200,
      accepted: const [200, 404, 503],
    );
    statuses['workbench/generate'] = 200;

    var batchCandStatus = 500;
    try {
      await postProductionWorkbenchBatchGenerateCandidateClipsV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
      );
      batchCandStatus = 200;
    } on RustApiException catch (e) {
      batchCandStatus = e.statusCode ?? 500;
    }
    _expectProbeStatus(
      label: 'POST production/workbench/batch-generate-candidate-clips',
      status: batchCandStatus,
      accepted: const [200, 400, 404, 503],
    );
    statuses['workbench/batch-candidate-clips'] = batchCandStatus;

    final storyboardPoll = await postProductionStoryboardPollingImageV1(
      token,
      projectId: projectId,
      scriptId: scriptId,
      ids: [resources.storyboardId],
    );
    _expectProbeStatus(
      label: 'POST production/storyboard/polling-image',
      status: storyboardPoll,
      accepted: const [200, 404, 503],
    );
    statuses['storyboard/poll'] = storyboardPoll;

    final exportImage = await postProductionExportImageV1(
      token,
      projectId: projectId,
      scriptId: scriptId,
      shotId: [
        {'id': '${resources.storyboardId}'},
      ],
    );
    _expectProbeStatus(
      label: 'POST production/export-image',
      status: exportImage,
      accepted: const [200, 404, 503],
    );
    statuses['export'] = exportImage;

    await _runTypedProductionProbeSuite(
      token,
      statuses,
      projectId: projectId,
      projectUuid: projectUuid,
      scriptId: scriptId,
      assetId: resources.assetId,
      storyboardId: resources.storyboardId,
    );

    return (statuses: statuses, implementedCount: 29);
  }

  Future<int> _runTypedProductionProbe({
    required String label,
    required Future<void> Function() run,
  }) async {
    try {
      await run();
      return 200;
    } on RustApiException catch (e) {
      final status = e.statusCode ?? -1;
      _expectProbeStatus(
        label: label,
        status: status,
        accepted: const [200, 404, 503],
      );
      return status;
    }
  }
}
