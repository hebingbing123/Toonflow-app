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

    statuses['prod/assets.batch'] = await _runTypedProductionProbe(
      label: 'POST production/assets/batch-generate-assets-image',
      run: () => postProductionAssetsBatchGenerateAssetsImageV1(
        token,
        projectId: 1,
        scriptId: 1,
        assetIds: const [1],
      ),
    );
    statuses['prod/assets.delete'] = await _runTypedProductionProbe(
      label: 'POST production/assets/delete-assets-derivative',
      run: () => postProductionAssetsDeleteAssetsDerivativeV1(
        token,
        projectId: 1,
        scriptId: 1,
        assetIds: const [1],
      ),
    );
    statuses['prod/assets.data'] = await _runTypedProductionProbe(
      label: 'POST production/assets/get-assets-data',
      run: () =>
          postProductionAssetsGetAssetsDataV1(token, projectId: 1, scriptId: 1),
    );
    statuses['prod/assets.poll'] = await _runTypedProductionProbe(
      label: 'POST production/assets/polling-image',
      run: () => postProductionAssetsPollingImageV1(
        token,
        projectId: 1,
        scriptId: 1,
        assetIds: const [1],
      ),
    );
    statuses['prod/assets.url'] = await _runTypedProductionProbe(
      label: 'POST production/assets/update-assets-url',
      run: () => postProductionAssetsUpdateAssetsUrlV1(
        token,
        projectId: 1,
        scriptId: 1,
        assetId: 1,
        imageUrl: 'https://example.com/probe.png',
      ),
    );
    statuses['prod/storyboard.data'] = await _runTypedProductionProbe(
      label: 'POST production/get-storyboard-data',
      run: () =>
          postProductionGetStoryboardDataV1(token, projectId: 1, scriptId: 1),
    );
    statuses['prod/storyboard.add'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/add',
      run: () => postStoryboardAddV1(
        token,
        projectId: 1,
        scriptId: 1,
        prompt: 'probe storyboard',
      ),
    );
    statuses['prod/storyboard.batch-add'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/batch-add-info',
      run: () => postStoryboardBatchAddInfoV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboards: const [
          StoryboardBatchAddInfoItem(prompt: 'probe storyboard'),
        ],
      ),
    );
    statuses['prod/storyboard.batch-gen'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/batch-generate-image',
      run: () => postStoryboardBatchGenerateImageV1(
        token,
        projectId: 1,
        scriptId: 1,
        items: const [
          BatchGenerateImageItem(storyboardId: 1, prompt: 'probe storyboard'),
        ],
      ),
    );
    statuses['prod/storyboard.down'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/down-preview-image',
      run: () => postStoryboardDownPreviewImageV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboardId: 1,
      ),
    );
    statuses['prod/storyboard.edit'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/edit-info',
      run: () => postStoryboardEditInfoV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboardId: 1,
        prompt: 'probe storyboard',
      ),
    );
    statuses['prod/storyboard.get'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/get-data',
      run: () => postStoryboardGetDataV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboardId: 1,
      ),
    );
    statuses['prod/storyboard.preview'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/preview-image',
      run: () => postStoryboardPreviewImageV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboardId: 1,
      ),
    );
    statuses['prod/storyboard.remove'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/remove-frame',
      run: () => postStoryboardRemoveFrameV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboardId: 1,
      ),
    );
    statuses['prod/storyboard.url'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/update-url',
      run: () => postStoryboardUpdateUrlV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboardId: 1,
        imageUrl: 'https://example.com/probe.png',
      ),
    );
    statuses['prod/edit.default-model'] = await _runTypedProductionProbe(
      label: 'POST production/edit-image/get-image-default-model',
      run: () => postProductionEditImageGetImageDefaultModelV1(token),
    );
    statuses['prod/edit.flow'] = await _runTypedProductionProbe(
      label: 'POST production/edit-image/get-image-flow',
      run: () => postProductionEditImageGetImageFlowV1(token),
    );
    statuses['prod/edit.save'] = await _runTypedProductionProbe(
      label: 'POST production/edit-image/save-image-flow',
      run: () => postProductionEditImageSaveImageFlowV1(
        token,
        flowId: 'img-flow-001',
        steps: const [
          {'stepId': 'upload', 'stepName': 'Upload', 'status': 'pending'},
        ],
      ),
    );
    statuses['prod/edit.update'] = await _runTypedProductionProbe(
      label: 'POST production/edit-image/update-image-flow',
      run: () => postProductionEditImageUpdateImageFlowV1(
        token,
        flowId: 'img-flow-001',
        stepId: 'upload',
        updates: const {'status': 'completed'},
      ),
    );
    statuses['prod/edit.generate'] = await _runTypedProductionProbe(
      label: 'POST production/edit-image/generate-flow-image',
      run: () => postProductionEditImageGenerateFlowImageV1(
        token,
        flowId: 'img-flow-001',
        prompt: 'probe',
      ),
    );
    statuses['prod/edit.upload'] = await _runTypedProductionProbe(
      label: 'POST production/edit-image/upload-image',
      run: () => postProductionEditImageUploadImageV1(
        token,
        projectId: 1,
        scriptId: 1,
        base64Data: 'data:image/png;base64,AA==',
      ),
    );
    statuses['prod/workbench.add-track'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/add-track',
      run: () => postWorkbenchAddTrackV1(
        token,
        projectId: 1,
        scriptId: 1,
        trackName: 'probe',
      ),
    );
    statuses['prod/workbench.del-track'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/delete-track',
      run: () => postWorkbenchDeleteTrackV1(
        token,
        projectId: 1,
        scriptId: 1,
        trackId: 1,
      ),
    );
    statuses['prod/workbench.del-video'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/delete-video',
      run: () => postWorkbenchDeleteVideoV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboardId: 1,
      ),
    );
    statuses['prod/workbench.prompt'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/generate-video-prompt',
      run: () =>
          postWorkbenchGenerateVideoPromptV1(token, projectId: 1, scriptId: 1),
    );
    statuses['prod/workbench.gen-data'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/get-generate-data',
      run: () =>
          postWorkbenchGetGenerateDataV1(token, projectId: 1, scriptId: 1),
    );
    statuses['prod/workbench.list'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/get-video-list',
      run: () => postWorkbenchGetVideoListV1(token, projectId: 1),
    );
    statuses['prod/workbench.model-detail'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/get-video-model-detail',
      run: () => postWorkbenchGetVideoModelDetailV1(token),
    );
    statuses['prod/workbench.select'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/select-video',
      run: () => postWorkbenchSelectVideoV1(
        token,
        projectId: 1,
        scriptId: 1,
        storyboardId: 1,
        videoUrl: 'https://example.com/probe.mp4',
      ),
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
