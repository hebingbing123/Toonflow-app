part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogProductionProbe on _HomePageState {
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

    final getData = await postProductionGetProductionDataV1(
      token,
      projectId: scope.projectId,
      scriptId: scope.scriptId,
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
      projectId: scope.projectId,
      episodesId: scope.scriptId,
    );
    _expectProbeStatus(
      label: 'POST production/get-flow-data',
      status: flowData,
      accepted: const [200, 404, 503],
    );
    statuses['flow'] = flowData;

    final flowSave = await postProductionSaveFlowDataV1(
      token,
      projectId: scope.projectId,
      episodesId: scope.scriptId,
    );
    _expectProbeStatus(
      label: 'POST production/save-flow-data',
      status: flowSave,
      accepted: const [200, 404, 503],
    );
    statuses['save'] = flowSave;

    await postProductionWorkbenchGenerateVideoV1(
      token,
      projectId: scope.projectId,
      scriptId: scope.scriptId,
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
        projectId: scope.projectId,
        scriptId: scope.scriptId,
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
      projectId: scope.projectId,
      scriptId: scope.scriptId,
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
      projectId: scope.projectId,
      scriptId: scope.scriptId,
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
      projectId: scope.projectId,
      scriptId: scope.scriptId,
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
