// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageSystemProbesModelsCatalog on _HomePageState {
  Future<void> _callModelsCatalog() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingModelsCatalog = true;
      _error = null;
      _modelsCatalogBody = null;
    });
    try {
      Future<int> productionAssetsProbeStatus(
        Future<void> Function() run,
      ) async {
        try {
          await run();
          return 200;
        } on RustApiException catch (e) {
          return e.statusCode ?? -1;
        }
      }

      Future<({int status, VendorMutationResponseV1? body})> vendorMutationProbe(
        Future<VendorMutationResponseV1> Function() run,
      ) async {
        try {
          final body = await run();
          return (status: 200, body: body);
        } on RustApiException catch (e) {
          return (status: e.statusCode ?? -1, body: null);
        }
      }

      final list = await fetchModelsCatalog(token, typeFilter: 'all');
      final vs = await fetchVendorsSummaryV1(token);
      final ad = await postAgentDeployListV1(token);
      final mt = await postSettingsVendorModelTestV1(
        token,
        modelName: 'gpt-4o-mini',
        type: 'text',
        id: '1',
      );
      final sap = await postScriptAgentGetPlanDataV1(token, projectId: 1);
      final ag = await postAssetsGenerateGenerateV1(
        token,
        projectId: 1,
        assetLegacyId: 1,
        model: '1:gpt-4o-mini',
        resolution: '1024x1024',
        type: 'role',
        name: 'probe',
        prompt: 'probe',
      );
      if (!mounted) return;
      if (!_vendorModelTestProbeOk(mt)) {
        setState(() {
          _error = 'POST vendors/model-test expected 200/429/503, got $mt';
          _loadingModelsCatalog = false;
        });
        return;
      }
      if (!_scriptAgentCatalogProbeOk(sap)) {
        setState(() {
          _error =
              'POST script-agent/get-plan-data expected 200/404/503, got $sap';
          _loadingModelsCatalog = false;
        });
        return;
      }
      if (!_assetsGenerateSingleJobProbeOk(ag)) {
        setState(() {
          _error =
              'POST assets-generate/generate expected 200/404/429/503, got $ag';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vendorAdd = await vendorMutationProbe(
        () => postSettingsVendorsAddV1(token, tsCode: 'export {}'),
      );
      final danger = await postSettingsDangerDeleteAllDataV1(token);
      final prod = await postProductionGetProductionDataV1(
        token,
        storyboardIds: const [1],
      );
      if (!mounted) return;
      if (!(vendorAdd.status == 200 || vendorAdd.status == 503)) {
        setState(() {
          _error =
              'POST settings/vendors/add expected 200/503, got ${vendorAdd.status}';
          _loadingModelsCatalog = false;
        });
        return;
      }
      if (danger != 501) {
        setState(() {
          _error =
              'POST settings/danger/delete-all-data expected 501, got $danger';
          _loadingModelsCatalog = false;
        });
        return;
      }
      if (!_productionProbeOk(prod)) {
        setState(() {
          _error =
              'POST production/get-production-data expected 200/404/503, got $prod';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final clearDb = await postSettingsDangerClearDatabaseV1(token);
      if (!mounted) return;
      if (clearDb != 501) {
        setState(() {
          _error =
              'POST settings/danger/clear-database expected 501, got $clearDb';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final deployM = await postSettingsAgentDeployModelV1(
        token,
        id: 1,
        name: '剧本Agent',
        model: 'x',
        modelName: 'y',
        vendorId: null,
        desc: 'z',
      );
      if (!mounted) return;
      if (deployM != 501) {
        setState(() {
          _error =
              'POST settings/agent-deploy/deploy-model expected 501, got $deployM';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final setKey = await postSettingsAgentDeploySetKeyV1(token);
      if (!mounted) return;
      if (setKey != 501) {
        setState(() {
          _error =
              'POST settings/agent-deploy/set-key expected 501, got $setKey';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vendorId = vendorAdd.body?.vendorId ?? 'probe-vendor';
      final vendorUpdate = await vendorMutationProbe(
        () => postSettingsVendorsUpdateV1(
          token,
          id: vendorId,
          displayName: 'Probe Vendor',
          selectedModels: const ['gpt-4o-mini'],
          settings: const {'timeout': '30'},
        ),
      );
      if (!mounted) return;
      if (!(vendorUpdate.status == 200 || vendorUpdate.status == 503)) {
        setState(() {
          _error =
              'POST settings/vendors/update expected 200/503, got ${vendorUpdate.status}';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vendorEnable = await vendorMutationProbe(
        () => postSettingsVendorsEnableV1(token, id: vendorId, enable: 1),
      );
      if (!mounted) return;
      if (!(vendorEnable.status == 200 || vendorEnable.status == 503)) {
        setState(() {
          _error =
              'POST settings/vendors/enable expected 200/503, got ${vendorEnable.status}';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vendorUpdateCode = await vendorMutationProbe(
        () => postSettingsVendorsUpdateCodeV1(
          token,
          id: vendorId,
          tsCode: '// probe',
        ),
      );
      if (!mounted) return;
      if (!(vendorUpdateCode.status == 200 || vendorUpdateCode.status == 503)) {
        setState(() {
          _error =
              'POST settings/vendors/update-code expected 200/503, got ${vendorUpdateCode.status}';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vendorFromLink = await vendorMutationProbe(
        () => postSettingsVendorsCodeFromLinkV1(
          token,
          link: 'https://example.com/a.ts',
        ),
      );
      if (!mounted) return;
      if (!(vendorFromLink.status == 200 || vendorFromLink.status == 503)) {
        setState(() {
          _error =
              'POST settings/vendors/code-from-link expected 200/503, got ${vendorFromLink.status}';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vendorDelete = await vendorMutationProbe(
        () => postSettingsVendorsDeleteV1(token, id: vendorId),
      );
      if (!mounted) return;
      if (!(vendorDelete.status == 200 ||
          vendorDelete.status == 404 ||
          vendorDelete.status == 503)) {
        setState(() {
          _error =
              'POST settings/vendors/delete expected 200/404/503, got ${vendorDelete.status}';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final saSet = await postScriptAgentSetPlanDataV1(token, projectId: 1);
      if (!mounted) return;
      if (!_scriptAgentCatalogProbeOk(saSet)) {
        setState(() {
          _error =
              'POST script-agent/set-plan-data expected 200/404/503, got $saSet';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final saUpd = await postScriptAgentUpdateDataV1(token, id: 1);
      if (!mounted) return;
      if (!_scriptAgentCatalogProbeOk(saUpd)) {
        setState(() {
          _error =
              'POST script-agent/update-data expected 200/404/503, got $saUpd';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final agPol = await postAssetsGeneratePolishPromptV1(
        token,
        assetsId: 1,
        projectId: 1,
        type: 'role',
        name: 'n',
        describe: 'd',
      );
      if (!mounted) return;
      if (!_assetsGenerateSingleJobProbeOk(agPol)) {
        setState(() {
          _error =
              'POST assets-generate/polish-prompt expected 200/404/429/503, got $agPol';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final agBat = await postAssetsGenerateBatchGenerateV1(
        token,
        projectId: 1,
        model: '1:x',
        resolution: '1024x1024',
        items: const [
          {'id': 1, 'type': 'role', 'name': 'n', 'prompt': 'p'},
        ],
      );
      if (!mounted) return;
      if (!_assetsGenerateSingleJobProbeOk(agBat)) {
        setState(() {
          _error =
              'POST assets-generate/batch-generate expected 200/404/429/503, got $agBat';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final agBap = await postAssetsGenerateBatchPolishV1(
        token,
        projectId: 1,
        items: const [
          {'assetsId': 1, 'type': 'role', 'name': 'n', 'describe': 'd'},
        ],
      );
      if (!mounted) return;
      if (!_assetsGenerateSingleJobProbeOk(agBap)) {
        setState(() {
          _error =
              'POST assets-generate/batch-polish expected 200/404/429/503, got $agBap';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prFlow = await postProductionGetFlowDataV1(
        token,
        projectId: 1,
        episodesId: 1,
      );
      if (!mounted) return;
      if (!_productionProbeOk(prFlow)) {
        setState(() {
          _error =
              'POST production/get-flow-data expected 200/404/503, got $prFlow';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prSave = await postProductionSaveFlowDataV1(
        token,
        projectId: 1,
        episodesId: 1,
      );
      if (!mounted) return;
      if (!_productionProbeOk(prSave)) {
        setState(() {
          _error =
              'POST production/save-flow-data expected 200/404/503, got $prSave';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prVid = await postProductionWorkbenchGenerateVideoV1(
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
      if (!mounted) return;
      if (!_productionProbeOk(prVid)) {
        setState(() {
          _error =
              'POST production/workbench/generate-video expected 200/404/503, got $prVid';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prPoll = await postProductionStoryboardPollingImageV1(
        token,
        ids: const [1],
      );
      if (!mounted) return;
      if (!_productionProbeOk(prPoll)) {
        setState(() {
          _error =
              'POST production/storyboard/polling-image expected 200/404/503, got $prPoll';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prExp = await postProductionExportImageV1(
        token,
        shotId: const [
          {'id': '1'},
        ],
      );
      if (!mounted) return;
      if (!_productionProbeOk(prExp)) {
        setState(() {
          _error =
              'POST production/export-image expected 200/404/503, got $prExp';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prAssetsBatch = await productionAssetsProbeStatus(
        () => postProductionAssetsBatchGenerateAssetsImageV1(
          token,
          projectId: 1,
          scriptId: 1,
          assetIds: const [1],
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prAssetsBatch)) {
        setState(() {
          _error =
              'POST production/assets/batch-generate-assets-image expected 200/404/503, got $prAssetsBatch';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prAssetsDelete = await productionAssetsProbeStatus(
        () => postProductionAssetsDeleteAssetsDerivativeV1(
          token,
          projectId: 1,
          assetIds: const [1],
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prAssetsDelete)) {
        setState(() {
          _error =
              'POST production/assets/delete-assets-derivative expected 200/404/503, got $prAssetsDelete';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prAssetsData = await productionAssetsProbeStatus(
        () => postProductionAssetsGetAssetsDataV1(token, projectId: 1),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prAssetsData)) {
        setState(() {
          _error =
              'POST production/assets/get-assets-data expected 200/404/503, got $prAssetsData';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prAssetsPoll = await productionAssetsProbeStatus(
        () => postProductionAssetsPollingImageV1(
          token,
          projectId: 1,
          assetIds: const [1],
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prAssetsPoll)) {
        setState(() {
          _error =
              'POST production/assets/polling-image expected 200/404/503, got $prAssetsPoll';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prAssetsUrl = await productionAssetsProbeStatus(
        () => postProductionAssetsUpdateAssetsUrlV1(
          token,
          projectId: 1,
          assetId: 1,
          imageUrl: 'https://example.com/probe.png',
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prAssetsUrl)) {
        setState(() {
          _error =
              'POST production/assets/update-assets-url expected 200/404/503, got $prAssetsUrl';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardData = await productionAssetsProbeStatus(
        () => postProductionGetStoryboardDataV1(
          token,
          projectId: 1,
          scriptId: 1,
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardData)) {
        setState(() {
          _error =
              'POST production/get-storyboard-data expected 200/404/503, got $prStoryboardData';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardAdd = await productionAssetsProbeStatus(
        () => postStoryboardAddV1(
          token,
          projectId: 1,
          scriptId: 1,
          prompt: 'probe storyboard',
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardAdd)) {
        setState(() {
          _error =
              'POST production/storyboard/add expected 200/404/503, got $prStoryboardAdd';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardBatchAdd = await productionAssetsProbeStatus(
        () => postStoryboardBatchAddInfoV1(
          token,
          projectId: 1,
          scriptId: 1,
          storyboards: const [
            StoryboardBatchAddInfoItem(prompt: 'probe storyboard'),
          ],
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardBatchAdd)) {
        setState(() {
          _error =
              'POST production/storyboard/batch-add-info expected 200/404/503, got $prStoryboardBatchAdd';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardBatchGenerate = await productionAssetsProbeStatus(
        () => postStoryboardBatchGenerateImageV1(
          token,
          projectId: 1,
          scriptId: 1,
          items: const [
            BatchGenerateImageItem(storyboardId: 1, prompt: 'probe storyboard'),
          ],
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardBatchGenerate)) {
        setState(() {
          _error =
              'POST production/storyboard/batch-generate-image expected 200/404/503, got $prStoryboardBatchGenerate';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardDownPreview = await productionAssetsProbeStatus(
        () => postStoryboardDownPreviewImageV1(token, storyboardId: 1),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardDownPreview)) {
        setState(() {
          _error =
              'POST production/storyboard/down-preview-image expected 200/404/503, got $prStoryboardDownPreview';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardEdit = await productionAssetsProbeStatus(
        () => postStoryboardEditInfoV1(
          token,
          storyboardId: 1,
          prompt: 'probe storyboard',
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardEdit)) {
        setState(() {
          _error =
              'POST production/storyboard/edit-info expected 200/404/503, got $prStoryboardEdit';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardGet = await productionAssetsProbeStatus(
        () => postStoryboardGetDataV1(token, storyboardId: 1),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardGet)) {
        setState(() {
          _error =
              'POST production/storyboard/get-data expected 200/404/503, got $prStoryboardGet';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardPreview = await productionAssetsProbeStatus(
        () => postStoryboardPreviewImageV1(token, storyboardId: 1),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardPreview)) {
        setState(() {
          _error =
              'POST production/storyboard/preview-image expected 200/404/503, got $prStoryboardPreview';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardRemove = await productionAssetsProbeStatus(
        () => postStoryboardRemoveFrameV1(token, storyboardId: 1),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardRemove)) {
        setState(() {
          _error =
              'POST production/storyboard/remove-frame expected 200/404/503, got $prStoryboardRemove';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prStoryboardUrl = await productionAssetsProbeStatus(
        () => postStoryboardUpdateUrlV1(
          token,
          storyboardId: 1,
          imageUrl: 'https://example.com/probe.png',
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prStoryboardUrl)) {
        setState(() {
          _error =
              'POST production/storyboard/update-url expected 200/404/503, got $prStoryboardUrl';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prEditDefaultModel = await productionAssetsProbeStatus(
        () => postProductionEditImageGetImageDefaultModelV1(token),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prEditDefaultModel)) {
        setState(() {
          _error =
              'POST production/edit-image/get-image-default-model expected 200/404/503, got $prEditDefaultModel';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prEditFlow = await productionAssetsProbeStatus(
        () => postProductionEditImageGetImageFlowV1(token),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prEditFlow)) {
        setState(() {
          _error =
              'POST production/edit-image/get-image-flow expected 200/404/503, got $prEditFlow';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prEditSave = await productionAssetsProbeStatus(
        () => postProductionEditImageSaveImageFlowV1(
          token,
          flowId: 'img-flow-001',
          steps: const [
            {'stepId': 'upload', 'stepName': 'Upload', 'status': 'pending'},
          ],
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prEditSave)) {
        setState(() {
          _error =
              'POST production/edit-image/save-image-flow expected 200/404/503, got $prEditSave';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prEditUpdate = await productionAssetsProbeStatus(
        () => postProductionEditImageUpdateImageFlowV1(
          token,
          flowId: 'img-flow-001',
          stepId: 'upload',
          updates: const {'status': 'completed'},
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prEditUpdate)) {
        setState(() {
          _error =
              'POST production/edit-image/update-image-flow expected 200/404/503, got $prEditUpdate';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prEditGenerate = await productionAssetsProbeStatus(
        () => postProductionEditImageGenerateFlowImageV1(
          token,
          flowId: 'img-flow-001',
          prompt: 'probe',
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prEditGenerate)) {
        setState(() {
          _error =
              'POST production/edit-image/generate-flow-image expected 200/404/503, got $prEditGenerate';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prWorkbenchAddTrack = await productionAssetsProbeStatus(
        () => postWorkbenchAddTrackV1(
          token,
          projectId: 1,
          scriptId: 1,
          trackName: 'probe',
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prWorkbenchAddTrack)) {
        setState(() {
          _error =
              'POST production/workbench/add-track expected 200/404/503, got $prWorkbenchAddTrack';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prWorkbenchDeleteTrack = await productionAssetsProbeStatus(
        () => postWorkbenchDeleteTrackV1(
          token,
          projectId: 1,
          scriptId: 1,
          trackId: 1,
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prWorkbenchDeleteTrack)) {
        setState(() {
          _error =
              'POST production/workbench/delete-track expected 200/404/503, got $prWorkbenchDeleteTrack';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prWorkbenchDeleteVideo = await productionAssetsProbeStatus(
        () => postWorkbenchDeleteVideoV1(
          token,
          projectId: 1,
          scriptId: 1,
          storyboardId: 1,
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prWorkbenchDeleteVideo)) {
        setState(() {
          _error =
              'POST production/workbench/delete-video expected 200/404/503, got $prWorkbenchDeleteVideo';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prWorkbenchPrompt = await productionAssetsProbeStatus(
        () => postWorkbenchGenerateVideoPromptV1(
          token,
          projectId: 1,
          scriptId: 1,
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prWorkbenchPrompt)) {
        setState(() {
          _error =
              'POST production/workbench/generate-video-prompt expected 200/404/503, got $prWorkbenchPrompt';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prWorkbenchGenerateData = await productionAssetsProbeStatus(
        () => postWorkbenchGetGenerateDataV1(
          token,
          projectId: 1,
          scriptId: 1,
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prWorkbenchGenerateData)) {
        setState(() {
          _error =
              'POST production/workbench/get-generate-data expected 200/404/503, got $prWorkbenchGenerateData';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prWorkbenchList = await productionAssetsProbeStatus(
        () => postWorkbenchGetVideoListV1(token, projectId: 1),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prWorkbenchList)) {
        setState(() {
          _error =
              'POST production/workbench/get-video-list expected 200/404/503, got $prWorkbenchList';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prWorkbenchModelDetail = await productionAssetsProbeStatus(
        () => postWorkbenchGetVideoModelDetailV1(token),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prWorkbenchModelDetail)) {
        setState(() {
          _error =
              'POST production/workbench/get-video-model-detail expected 200/404/503, got $prWorkbenchModelDetail';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final prWorkbenchSelect = await productionAssetsProbeStatus(
        () => postWorkbenchSelectVideoV1(
          token,
          projectId: 1,
          scriptId: 1,
          storyboardId: 1,
          videoUrl: 'https://example.com/probe.mp4',
        ),
      );
      if (!mounted) return;
      if (!_productionProbeOk(prWorkbenchSelect)) {
        setState(() {
          _error =
              'POST production/workbench/select-video expected 200/404/503, got $prWorkbenchSelect';
          _loadingModelsCatalog = false;
        });
        return;
      }
      setState(() {
        const typedProductionProbeCount = 28;
        final sample = list.take(4).map((m) => '${m.value}(${m.type})').join(', ');
        final modelsLine = list.isEmpty
            ? '(empty)'
            : '${list.length} models${sample.isEmpty ? '' : '; sample: $sample'}';
        final v0 = vs.vendors.isEmpty ? null : vs.vendors.first;
        final vendorsBit = v0 == null
            ? 'vendors: (empty)'
            : 'vendors: ${vs.vendors.length} · ${v0.name} kinds=${v0.modelKinds.join(",")} source=${vs.source}';
        final adBit =
            'agent-deploy: ${ad.length} rows · deploy-model->$deployM · set-key->$setKey · model-test -> $mt · script-agent/get-plan -> $sap · set-plan->$saSet · update->$saUpd · assets-gen -> $ag / polish->$agPol / batch->$agBat / batch-polish->$agBap · vendors real -> add:${vendorAdd.status}/upd:${vendorUpdate.status}/en:${vendorEnable.status}/code:${vendorUpdateCode.status}/link:${vendorFromLink.status}/del:${vendorDelete.status} · danger/delete-all -> $danger · clear-db -> $clearDb · production/get-data -> $prod · flow/save/workbench/poll/export -> $prFlow/$prSave/$prVid/$prPoll/$prExp · prod/assets typed -> $prAssetsBatch/$prAssetsDelete/$prAssetsData/$prAssetsPoll/$prAssetsUrl · prod/storyboard typed -> $prStoryboardData/$prStoryboardAdd/$prStoryboardBatchAdd/$prStoryboardBatchGenerate/$prStoryboardDownPreview/$prStoryboardEdit/$prStoryboardGet/$prStoryboardPreview/$prStoryboardRemove/$prStoryboardUrl · prod/edit-image typed -> $prEditDefaultModel/$prEditFlow/$prEditSave/$prEditUpdate/$prEditGenerate · prod/workbench typed -> $prWorkbenchAddTrack/$prWorkbenchDeleteTrack/$prWorkbenchDeleteVideo/$prWorkbenchPrompt/$prWorkbenchGenerateData/$prWorkbenchList/$prWorkbenchModelDetail/$prWorkbenchSelect · prod/implemented ${typedProductionProbeCount}x(200/404/503)';
        _modelsCatalogBody = '$modelsLine · $vendorsBit · $adBit';
        _loadingModelsCatalog = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingModelsCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingModelsCatalog = false;
      });
    }
  }
}
