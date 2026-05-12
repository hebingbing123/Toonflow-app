part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogProductionProbeTyped
    on _HomePageState {
  Future<void> _runTypedProductionProbeSuite(
    String token,
    Map<String, int> statuses, {
    required int projectId,
    String? projectUuid,
    required int scriptId,
    required int assetId,
    required int storyboardId,
    bool skipRequests = false,
  }) async {
    Future<int> skipOrRun({
      required String label,
      required Future<void> Function() run,
    }) async {
      if (!skipRequests) {
        return _runTypedProductionProbe(label: label, run: run);
      }
      const status = 404;
      _expectProbeStatus(
        label: label,
        status: status,
        accepted: const [200, 404, 503],
      );
      return status;
    }

    statuses['prod/assets.batch'] = await skipOrRun(
      label: 'POST production/assets/batch-generate-assets-image',
      run: () => postProductionAssetsBatchGenerateAssetsImageV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        assetIds: [assetId],
      ),
    );
    statuses['prod/assets.delete'] = await skipOrRun(
      label: 'POST production/assets/delete-assets-derivative',
      run: () => postProductionAssetsDeleteAssetsDerivativeV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        assetIds: [assetId],
      ),
    );
    statuses['prod/assets.data'] = await skipOrRun(
      label: 'POST production/assets/get-assets-data',
      run: () => postProductionAssetsGetAssetsDataV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
      ),
    );
    statuses['prod/assets.poll'] = await skipOrRun(
      label: 'POST production/assets/polling-image',
      run: () => postProductionAssetsPollingImageV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        assetIds: [assetId],
      ),
    );
    statuses['prod/assets.url'] = await skipOrRun(
      label: 'POST production/assets/update-assets-url',
      run: () => postProductionAssetsUpdateAssetsUrlV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        assetId: assetId,
        imageUrl: 'https://example.com/probe.png',
      ),
    );
    statuses['prod/storyboard.data'] = await skipOrRun(
      label: 'POST production/get-storyboard-data',
      run: () => postProductionGetStoryboardDataV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
      ),
    );
    statuses['prod/storyboard.add'] = await skipOrRun(
      label: 'POST production/storyboard/add',
      run: () => postStoryboardAddV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        prompt: 'probe storyboard',
      ),
    );
    statuses['prod/storyboard.batch-add'] = await skipOrRun(
      label: 'POST production/storyboard/batch-add-info',
      run: () => postStoryboardBatchAddInfoV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboards: const [
          StoryboardBatchAddInfoItem(prompt: 'probe storyboard'),
        ],
      ),
    );
    statuses['prod/storyboard.batch-gen'] = await skipOrRun(
      label: 'POST production/storyboard/batch-generate-image',
      run: () => postStoryboardBatchGenerateImageV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        items: [
          BatchGenerateImageItem(
            storyboardId: storyboardId,
            prompt: 'probe storyboard',
          ),
        ],
      ),
    );
    statuses['prod/storyboard.down'] = await skipOrRun(
      label: 'POST production/storyboard/down-preview-image',
      run: () => postStoryboardDownPreviewImageV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboardId: storyboardId,
      ),
    );
    statuses['prod/storyboard.edit'] = await skipOrRun(
      label: 'POST production/storyboard/edit-info',
      run: () => postStoryboardEditInfoV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboardId: storyboardId,
        prompt: 'probe storyboard',
      ),
    );
    statuses['prod/storyboard.get'] = await skipOrRun(
      label: 'POST production/storyboard/get-data',
      run: () => postStoryboardGetDataV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboardId: storyboardId,
      ),
    );
    statuses['prod/storyboard.preview'] = await skipOrRun(
      label: 'POST production/storyboard/preview-image',
      run: () => postStoryboardPreviewImageV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboardId: storyboardId,
      ),
    );
    statuses['prod/storyboard.remove'] = await skipOrRun(
      label: 'POST production/storyboard/remove-frame',
      run: () => postStoryboardRemoveFrameV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboardId: storyboardId,
      ),
    );
    statuses['prod/storyboard.url'] = await skipOrRun(
      label: 'POST production/storyboard/update-url',
      run: () => postStoryboardUpdateUrlV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboardId: storyboardId,
        imageUrl: 'https://example.com/probe.png',
      ),
    );
    statuses['prod/edit.default-model'] = await skipOrRun(
      label: 'POST production/edit-image/get-image-default-model',
      run: () => postProductionEditImageGetImageDefaultModelV1(token),
    );
    statuses['prod/edit.flow'] = await skipOrRun(
      label: 'POST production/edit-image/get-image-flow',
      run: () => postProductionEditImageGetImageFlowV1(token),
    );
    statuses['prod/edit.save'] = await skipOrRun(
      label: 'POST production/edit-image/save-image-flow',
      run: () => postProductionEditImageSaveImageFlowV1(
        token,
        flowId: 'img-flow-001',
        steps: const [
          {'stepId': 'upload', 'stepName': 'Upload', 'status': 'pending'},
        ],
      ),
    );
    statuses['prod/edit.update'] = await skipOrRun(
      label: 'POST production/edit-image/update-image-flow',
      run: () => postProductionEditImageUpdateImageFlowV1(
        token,
        flowId: 'img-flow-001',
        stepId: 'upload',
        updates: const {'status': 'completed'},
      ),
    );
    statuses['prod/edit.generate'] = await skipOrRun(
      label: 'POST production/edit-image/generate-flow-image',
      run: () => postProductionEditImageGenerateFlowImageV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        flowId: 'img-flow-001',
        prompt: 'probe',
      ),
    );
    statuses['prod/edit.upload'] = await skipOrRun(
      label: 'POST production/edit-image/upload-image',
      run: () => postProductionEditImageUploadImageV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        base64Data: 'data:image/png;base64,AA==',
      ),
    );
    statuses['prod/workbench.add-track'] = await skipOrRun(
      label: 'POST production/workbench/add-track',
      run: () => postWorkbenchAddTrackV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        trackName: 'probe',
      ),
    );
    statuses['prod/workbench.del-track'] = await skipOrRun(
      label: 'POST production/workbench/delete-track',
      run: () => postWorkbenchDeleteTrackV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
        trackId: 1,
      ),
    );
    statuses['prod/workbench.del-video'] = await skipOrRun(
      label: 'POST production/workbench/delete-video',
      run: () => postWorkbenchDeleteVideoV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboardId: storyboardId,
      ),
    );
    statuses['prod/workbench.prompt'] = await skipOrRun(
      label: 'POST production/workbench/generate-video-prompt',
      run: () => postWorkbenchGenerateVideoPromptV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
      ),
    );
    statuses['prod/workbench.gen-data'] = await skipOrRun(
      label: 'POST production/workbench/get-generate-data',
      run: () => postWorkbenchGetGenerateDataV1(
        token,
        projectId: projectId,
        scriptId: scriptId,
      ),
    );
    statuses['prod/workbench.list'] = await skipOrRun(
      label: 'POST production/workbench/get-video-list',
      run: () => postWorkbenchGetVideoListV1(token, projectId: projectId),
    );
    statuses['prod/workbench.model-detail'] = await skipOrRun(
      label: 'POST production/workbench/get-video-model-detail',
      run: () => postWorkbenchGetVideoModelDetailV1(token),
    );
    statuses['prod/workbench.select'] = await skipOrRun(
      label: 'POST production/workbench/select-video',
      run: () => postWorkbenchSelectVideoV1(
        token,
        projectId: projectId,
        projectUuid: projectUuid,
        scriptId: scriptId,
        storyboardId: storyboardId,
        videoUrl: 'https://example.com/probe.mp4',
      ),
    );
    statuses['prod/workbench.media-op'] = await skipOrRun(
      label: 'POST production/workbench/storyboard-media-op',
      run: () => postWorkbenchStoryboardMediaOpV1(
        token,
        buildStoryboardMediaOpBodyV1(
          base: <String, dynamic>{
            'op': 'selectVideo',
            'scriptId': scriptId,
            'storyboardId': storyboardId,
            'videoUrl': 'https://example.com/probe.mp4',
          },
          projectId: projectId,
          projectUuid: projectUuid,
        ),
      ),
    );
  }
}
