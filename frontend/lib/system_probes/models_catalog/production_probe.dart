part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogProductionProbe on _HomePageState {
  Future<({Map<String, int> statuses, int implementedCount})>
  _runModelsCatalogProductionProbes(String token) async {
    final statuses = <String, int>{};

    final getData = await postProductionGetProductionDataV1(
      token,
      projectId: 1,
      scriptId: 1,
      storyboardIds: const [1],
    );
    _expectProbeStatus(
      label: 'POST production/get-production-data',
      status: getData,
      accepted: const [200, 404, 503],
    );
    statuses['production/get-data'] = getData;

    final flowData = await postProductionGetFlowDataV1(
      token,
      projectId: 1,
      episodesId: 1,
    );
    _expectProbeStatus(
      label: 'POST production/get-flow-data',
      status: flowData,
      accepted: const [200, 404, 503],
    );
    statuses['flow'] = flowData;

    final flowSave = await postProductionSaveFlowDataV1(
      token,
      projectId: 1,
      episodesId: 1,
    );
    _expectProbeStatus(
      label: 'POST production/save-flow-data',
      status: flowSave,
      accepted: const [200, 404, 503],
    );
    statuses['save'] = flowSave;

    final generateVideo = await postProductionWorkbenchGenerateVideoV1(
      token,
      projectId: 1,
      scriptId: 1,
      uploadData: const [
        {'id': 1, 'sources': 'assets'},
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
      status: generateVideo,
      accepted: const [200, 404, 503],
    );
    statuses['workbench/generate'] = generateVideo;

    final storyboardPoll = await postProductionStoryboardPollingImageV1(
      token,
      projectId: 1,
      scriptId: 1,
      ids: const [1],
    );
    _expectProbeStatus(
      label: 'POST production/storyboard/polling-image',
      status: storyboardPoll,
      accepted: const [200, 404, 503],
    );
    statuses['storyboard/poll'] = storyboardPoll;

    final exportImage = await postProductionExportImageV1(
      token,
      projectId: 1,
      scriptId: 1,
      shotId: const [
        {'id': '1'},
      ],
    );
    _expectProbeStatus(
      label: 'POST production/export-image',
      status: exportImage,
      accepted: const [200, 404, 503],
    );
    statuses['export'] = exportImage;

    await _runTypedProductionProbeSuite(token, statuses);

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
