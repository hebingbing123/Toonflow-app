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
              'POST script-agent/get-plan-data expected 200/404/501/503, got $sap';
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
      final vadd = await postSettingsVendorsAddV1(token, tsCode: 'export {}');
      final danger = await postSettingsDangerDeleteAllDataV1(token);
      final prod = await postProductionGetProductionDataV1(
        token,
        storyboardIds: const [1],
      );
      if (!mounted) return;
      if (vadd != 501) {
        setState(() {
          _error = 'POST settings/vendors/add expected 501, got $vadd';
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
      final vUp = await postSettingsVendorsUpdateV1(
        token,
        id: 'openai',
        inputs: const [],
        models: const [],
      );
      if (!mounted) return;
      if (vUp != 501) {
        setState(() {
          _error = 'POST settings/vendors/update expected 501, got $vUp';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vDel = await postSettingsVendorsDeleteV1(token, id: 'openai');
      if (!mounted) return;
      if (vDel != 501) {
        setState(() {
          _error = 'POST settings/vendors/delete expected 501, got $vDel';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vEn = await postSettingsVendorsEnableV1(
        token,
        id: 'openai',
        enable: 1,
      );
      if (!mounted) return;
      if (vEn != 501) {
        setState(() {
          _error = 'POST settings/vendors/enable expected 501, got $vEn';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vCode = await postSettingsVendorsUpdateCodeV1(
        token,
        id: 'openai',
        tsCode: '//',
      );
      if (!mounted) return;
      if (vCode != 501) {
        setState(() {
          _error = 'POST settings/vendors/update-code expected 501, got $vCode';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final vLink = await postSettingsVendorsCodeFromLinkV1(
        token,
        link: 'https://example.com/a.ts',
      );
      if (!mounted) return;
      if (vLink != 501) {
        setState(() {
          _error =
              'POST settings/vendors/code-from-link expected 501, got $vLink';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final saSet = await postScriptAgentSetPlanDataV1(token, projectId: 1);
      if (!mounted) return;
      if (!_scriptAgentCatalogProbeOk(saSet)) {
        setState(() {
          _error =
              'POST script-agent/set-plan-data expected 200/404/501/503, got $saSet';
          _loadingModelsCatalog = false;
        });
        return;
      }
      final saUpd = await postScriptAgentUpdateDataV1(token, id: 1);
      if (!mounted) return;
      if (!_scriptAgentCatalogProbeOk(saUpd)) {
        setState(() {
          _error =
              'POST script-agent/update-data expected 200/404/501/503, got $saUpd';
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
      const productionBodies = <String, Map<String, dynamic>>{
        '/api/v1/production/edit-image/generate-flow-image': {
          'flowId': 'img-flow-001',
          'prompt': 'probe',
        },
        '/api/v1/production/edit-image/get-image-default-model': {},
        '/api/v1/production/edit-image/get-image-flow': {},
        '/api/v1/production/edit-image/save-image-flow': {
          'flowId': 'img-flow-001',
          'steps': [
            {'stepId': 'upload', 'status': 'pending'},
          ],
        },
        '/api/v1/production/edit-image/update-image-flow': {
          'flowId': 'img-flow-001',
          'stepId': 'upload',
          'updates': {},
        },
        '/api/v1/production/get-storyboard-data': {
          'projectId': 1,
          'scriptId': 1,
        },
        '/api/v1/production/storyboard/add': {
          'projectId': 1,
          'scriptId': 1,
          'prompt': 'probe storyboard',
        },
        '/api/v1/production/storyboard/batch-add-info': {
          'projectId': 1,
          'scriptId': 1,
          'storyboards': [
            {'prompt': 'probe storyboard'},
          ],
        },
        '/api/v1/production/storyboard/batch-generate-image': {
          'projectId': 1,
          'scriptId': 1,
          'items': [
            {'storyboardId': 1, 'prompt': 'probe storyboard'},
          ],
        },
        '/api/v1/production/storyboard/down-preview-image': {'storyboardId': 1},
        '/api/v1/production/storyboard/edit-info': {
          'storyboardId': 1,
          'prompt': 'probe storyboard',
        },
        '/api/v1/production/storyboard/get-data': {'storyboardId': 1},
        '/api/v1/production/storyboard/preview-image': {'storyboardId': 1},
        '/api/v1/production/storyboard/remove-frame': {'storyboardId': 1},
        '/api/v1/production/storyboard/update-url': {
          'storyboardId': 1,
          'imageUrl': 'https://example.com/probe.png',
        },
        '/api/v1/production/workbench/add-track': {
          'projectId': 1,
          'scriptId': 1,
          'trackName': 'probe',
        },
        '/api/v1/production/workbench/delete-track': {
          'projectId': 1,
          'scriptId': 1,
          'trackId': 1,
        },
        '/api/v1/production/workbench/delete-video': {
          'projectId': 1,
          'scriptId': 1,
          'storyboardId': 1,
        },
        '/api/v1/production/workbench/generate-video-prompt': {
          'projectId': 1,
          'scriptId': 1,
        },
        '/api/v1/production/workbench/get-generate-data': {
          'projectId': 1,
          'scriptId': 1,
        },
        '/api/v1/production/workbench/get-video-list': {'projectId': 1},
        '/api/v1/production/workbench/get-video-model-detail': {},
        '/api/v1/production/workbench/select-video': {
          'projectId': 1,
          'scriptId': 1,
          'storyboardId': 1,
          'videoUrl': 'https://example.com/probe.mp4',
        },
      };
      const prodPrefix = '/api/v1/production/';
      for (final entry in productionBodies.entries) {
        final path = entry.key;
        final code = await postProductionLegacyJsonStubV1(
          token,
          path,
          body: entry.value,
        );
        if (!mounted) return;
        if (!_productionProbeOk(code)) {
          final rel = path.startsWith(prodPrefix)
              ? path.substring(prodPrefix.length)
              : path;
          setState(() {
            _error = 'POST production/$rel expected 200/404/503, got $code';
            _loadingModelsCatalog = false;
          });
          return;
        }
      }
      setState(() {
        const typedProductionAssetsCount = 5;
        final sample = list.take(4).map((m) => '${m.value}(${m.type})').join(', ');
        final modelsLine = list.isEmpty
            ? '(empty)'
            : '${list.length} models${sample.isEmpty ? '' : '; sample: $sample'}';
        final v0 = vs.vendors.isEmpty ? null : vs.vendors.first;
        final vendorsBit = v0 == null
            ? 'vendors: (empty)'
            : 'vendors: ${vs.vendors.length} · ${v0.name} kinds=${v0.modelKinds.join(",")} source=${vs.source}';
        final adBit =
            'agent-deploy: ${ad.length} rows · deploy-model->$deployM · set-key->$setKey · model-test -> $mt · script-agent/get-plan -> $sap · set-plan->$saSet · update->$saUpd · assets-gen -> $ag / polish->$agPol / batch->$agBat / batch-polish->$agBap · vendors/add -> $vadd · vend stubs -> $vUp/$vDel/$vEn/$vCode/$vLink · danger/delete-all -> $danger · clear-db -> $clearDb · production/get-data -> $prod · flow/save/workbench/poll/export -> $prFlow/$prSave/$prVid/$prPoll/$prExp · prod/assets typed -> $prAssetsBatch/$prAssetsDelete/$prAssetsData/$prAssetsPoll/$prAssetsUrl · prod/implemented ${typedProductionAssetsCount + productionBodies.length}x(200/404/503)';
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
