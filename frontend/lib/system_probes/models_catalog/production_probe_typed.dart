part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogProductionProbeTyped
    on _HomePageState {
  Future<void> _runTypedProductionProbeSuite(
    String token,
    Map<String, int> statuses, {
    required int projectId,
    required int scriptId,
  }) async {
    statuses['prod/assets.batch'] = await _runTypedProductionProbe(
      label: 'POST production/assets/batch-generate-assets-image',
      run: () => postProductionAssetsBatchGenerateAssetsImageV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        assetIds: const [1],
      ),
    );
    statuses['prod/assets.delete'] = await _runTypedProductionProbe(
      label: 'POST production/assets/delete-assets-derivative',
      run: () => postProductionAssetsDeleteAssetsDerivativeV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        assetIds: const [1],
      ),
    );
    statuses['prod/assets.data'] = await _runTypedProductionProbe(
      label: 'POST production/assets/get-assets-data',
      run: () => postProductionAssetsGetAssetsDataV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
      ),
    );
    statuses['prod/assets.poll'] = await _runTypedProductionProbe(
      label: 'POST production/assets/polling-image',
      run: () => postProductionAssetsPollingImageV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        assetIds: const [1],
      ),
    );
    statuses['prod/assets.url'] = await _runTypedProductionProbe(
      label: 'POST production/assets/update-assets-url',
      run: () => postProductionAssetsUpdateAssetsUrlV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        assetId: 1,
        imageUrl: 'https://example.com/probe.png',
      ),
    );
    statuses['prod/storyboard.data'] = await _runTypedProductionProbe(
      label: 'POST production/get-storyboard-data',
      run: () => postProductionGetStoryboardDataV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
      ),
    );
    statuses['prod/storyboard.add'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/add',
      run: () => postStoryboardAddV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        prompt: 'probe storyboard',
      ),
    );
    statuses['prod/storyboard.batch-add'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/batch-add-info',
      run: () => postStoryboardBatchAddInfoV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboards: const [
          StoryboardBatchAddInfoItem(prompt: 'probe storyboard'),
        ],
      ),
    );
    statuses['prod/storyboard.batch-gen'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/batch-generate-image',
      run: () => postStoryboardBatchGenerateImageV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        items: const [
          BatchGenerateImageItem(storyboardId: 1, prompt: 'probe storyboard'),
        ],
      ),
    );
    statuses['prod/storyboard.down'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/down-preview-image',
      run: () => postStoryboardDownPreviewImageV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboardId: 1,
      ),
    );
    statuses['prod/storyboard.edit'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/edit-info',
      run: () => postStoryboardEditInfoV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboardId: 1,
        prompt: 'probe storyboard',
      ),
    );
    statuses['prod/storyboard.get'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/get-data',
      run: () => postStoryboardGetDataV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboardId: 1,
      ),
    );
    statuses['prod/storyboard.preview'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/preview-image',
      run: () => postStoryboardPreviewImageV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboardId: 1,
      ),
    );
    statuses['prod/storyboard.remove'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/remove-frame',
      run: () => postStoryboardRemoveFrameV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboardId: 1,
      ),
    );
    statuses['prod/storyboard.url'] = await _runTypedProductionProbe(
      label: 'POST production/storyboard/update-url',
      run: () => postStoryboardUpdateUrlV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
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
        projectId: projectId,
        scriptId: scriptId,
        flowId: 'img-flow-001',
        prompt: 'probe',
      ),
    );
    statuses['prod/edit.upload'] = await _runTypedProductionProbe(
      label: 'POST production/edit-image/upload-image',
      run: () => postProductionEditImageUploadImageV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        base64Data: 'data:image/png;base64,AA==',
      ),
    );
    statuses['prod/workbench.add-track'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/add-track',
      run: () => postWorkbenchAddTrackV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        trackName: 'probe',
      ),
    );
    statuses['prod/workbench.del-track'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/delete-track',
      run: () => postWorkbenchDeleteTrackV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        trackId: 1,
      ),
    );
    statuses['prod/workbench.del-video'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/delete-video',
      run: () => postWorkbenchDeleteVideoV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboardId: 1,
      ),
    );
    statuses['prod/workbench.prompt'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/generate-video-prompt',
      run: () => postWorkbenchGenerateVideoPromptV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
      ),
    );
    statuses['prod/workbench.gen-data'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/get-generate-data',
      run: () => postWorkbenchGetGenerateDataV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
      ),
    );
    statuses['prod/workbench.list'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/get-video-list',
      run: () => postWorkbenchGetVideoListV1(token, projectId: projectId),
    );
    statuses['prod/workbench.model-detail'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/get-video-model-detail',
      run: () => postWorkbenchGetVideoModelDetailV1(token),
    );
    statuses['prod/workbench.select'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/select-video',
      run: () => postWorkbenchSelectVideoV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        storyboardId: 1,
        videoUrl: 'https://example.com/probe.mp4',
      ),
    );
    statuses['prod/workbench.media-op'] = await _runTypedProductionProbe(
      label: 'POST production/workbench/storyboard-media-op',
      run: () => postWorkbenchStoryboardMediaOpV1(token, <String, dynamic>{
        'op': 'selectVideo',
        'projectId': projectId,
        'scriptId': scriptId,
        'storyboardId': 1,
        'videoUrl': 'https://example.com/probe.mp4',
      }),
    );
  }
}
