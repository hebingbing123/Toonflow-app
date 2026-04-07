// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageSystemProbesController on _HomePageState {
  Future<void> _callMe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingMe = true;
      _error = null;
      _meBody = null;
    });
    try {
      final r = await fetchMeV1(token);
      if (!mounted) return;
      final parts = <String>['sub=${r.sub}', 'plan_tier=${r.planTier}'];
      if (r.email != null && r.email!.isNotEmpty) {
        parts.add('email=${r.email}');
      }
      if (r.billingCurrency != null && r.billingCurrency!.isNotEmpty) {
        parts.add('billing_currency=${r.billingCurrency}');
      }
      if (r.billingProvider != null && r.billingProvider!.isNotEmpty) {
        parts.add('billing_provider=${r.billingProvider}');
      }
      setState(() {
        _meBody = parts.join(' · ');
        _loadingMe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMe = false;
      });
    }
  }

  Future<void> _callDevSwitchProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingDevSwitchProbe = true;
      _error = null;
      _devSwitchProbeBody = null;
    });
    try {
      final g = await fetchSwitchAiDevToolV1(token);
      final target = g.value == '1' ? '0' : '1';
      final put = await putSwitchAiDevToolV1(token, target);
      final after = await fetchSwitchAiDevToolV1(token);
      if (!mounted) return;
      if (put.value != target || after.value != target) {
        setState(() {
          _error =
              'PUT switch-ai-tool expected value=$target, got put=${put.value} get=${after.value}';
          _loadingDevSwitchProbe = false;
        });
        return;
      }
      setState(() {
        _devSwitchProbeBody =
            'GET value=${g.value} · PUT body {value:$target} -> ${put.value} · GET value=${after.value}';
        _loadingDevSwitchProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDevSwitchProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDevSwitchProbe = false;
      });
    }
  }

  Future<void> _callMemoryConfigProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingMemoryConfigProbe = true;
      _error = null;
      _memoryConfigProbeBody = null;
    });
    try {
      final orig = await fetchMemoryConfigV1(token);
      final probeRag = orig.ragLimit == 42 ? 43 : 42;
      final patched = orig.copyWith(ragLimit: probeRag);
      final msg = await postMemoryConfigV1(token, patched);
      final mid = await fetchMemoryConfigV1(token);
      await postMemoryConfigV1(token, orig);
      final fin = await fetchMemoryConfigV1(token);
      if (!mounted) return;
      if (mid.ragLimit != probeRag) {
        setState(() {
          _error = 'memory-config POST did not stick: ragLimit ${mid.ragLimit}';
          _loadingMemoryConfigProbe = false;
        });
        return;
      }
      if (fin.ragLimit != orig.ragLimit) {
        setState(() {
          _error =
              'memory-config restore failed: expected ragLimit ${orig.ragLimit}, got ${fin.ragLimit}';
          _loadingMemoryConfigProbe = false;
        });
        return;
      }
      final line =
          'GET ragLimit=${orig.ragLimit} · POST -> "$msg" · GET ragLimit=${mid.ragLimit} · restored';
      var legacyForClear = 1;
      try {
        final plist = await fetchProjects(token);
        if (plist.isNotEmpty) {
          legacyForClear = plist.first.legacyId;
        }
      } on RustApiException catch (_) {
        // Keep default **1** (often **404** when DB up but empty / no such legacy).
      }
      final clr = await postSettingsClearAgentMemoriesV1(
        token,
        projectId: legacyForClear,
        agentType: 'scriptAgent',
      );
      if (!mounted) return;
      final okClear = clr == 503 || clr == 200 || clr == 404;
      if (!okClear) {
        setState(() {
          _error =
              'POST clear-agent-memories expected 503/200/404, got $clr (legacy #$legacyForClear)';
          _loadingMemoryConfigProbe = false;
        });
        return;
      }
      final clearNote = switch (clr) {
        503 => '503 no DB',
        200 => '200 ok',
        404 => '404 no project legacy#$legacyForClear',
        _ => '$clr',
      };
      setState(() {
        _memoryConfigProbeBody = '$line · clear-agent-memories -> $clearNote';
        _loadingMemoryConfigProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMemoryConfigProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMemoryConfigProbe = false;
      });
    }
  }

  Future<void> _callAboutProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingAboutProbe = true;
      _error = null;
      _aboutProbeBody = null;
    });
    try {
      final cu = await postAboutCheckUpdateV1(token, 'toonflow');
      final dl = await postAboutDownloadAppV1(
        token,
        url: 'https://example.com/toonflow-setup.dmg',
        reinstall: true,
      );
      if (!mounted) return;
      if (dl != 501) {
        setState(() {
          _error = 'POST download-app expected 501, got $dl';
          _loadingAboutProbe = false;
        });
        return;
      }
      setState(() {
        _aboutProbeBody =
            'check-update: needUpdate=${cu.needUpdate} latest=${cu.latestVersion} · download-app -> $dl';
        _loadingAboutProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAboutProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAboutProbe = false;
      });
    }
  }

  Future<void> _callUsageSummary() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingUsageSummary = true;
      _error = null;
      _usageSummaryBody = null;
    });
    try {
      final u = await fetchUsageSummary(token);
      if (!mounted) return;
      setState(() {
        _usageSummaryBody =
            'events_last_24h=${u.eventsLast24h} · events_last_7d=${u.eventsLast7d} · event_counts_last_7d=${u.eventCountsLast7d}';
        _loadingUsageSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingUsageSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingUsageSummary = false;
      });
    }
  }

  Future<void> _callPromptsProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingPromptsProbe = true;
      _error = null;
      _promptsProbeBody = null;
    });
    try {
      final rows = await fetchPromptsV1(token);
      if (!mounted) return;
      final types = rows.map((r) => r.type).join(', ');
      final totalChars = rows.fold<int>(0, (a, r) => a + r.data.length);
      var roundtrip = '';
      final r1s = rows.where((r) => r.id == 1);
      if (r1s.isNotEmpty) {
        final r1 = r1s.first;
        try {
          await fetchPromptByLegacyIdV1(token, 1);
          final patched = await patchPromptByLegacyIdV1(token, 1, r1.data);
          roundtrip = ' · GET/1+PATCH/1 ok (data_len=${patched.data.length})';
        } on RustApiException catch (e) {
          roundtrip = ' · GET/1+PATCH/1 -> ${e.statusCode}';
        }
      }
      setState(() {
        _promptsProbeBody =
            'count=${rows.length} · types=$types · data_chars_total=$totalChars$roundtrip';
        _loadingPromptsProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPromptsProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPromptsProbe = false;
      });
    }
  }

  Future<void> _callVisualManualProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingVisualManualProbe = true;
      _error = null;
      _visualManualProbeBody = null;
    });
    try {
      final vm = await fetchVisualManualV1(token);
      final vmPost = await fetchVisualManualPostV1(token);
      if (!mounted) return;
      if (vm.styles.length != vmPost.styles.length) {
        setState(() {
          _error =
              'visual-manual GET/POST style count mismatch: ${vm.styles.length} vs ${vmPost.styles.length}';
          _loadingVisualManualProbe = false;
        });
        return;
      }
      var totalChars = 0;
      var totalImages = 0;
      for (final s in vm.styles) {
        totalImages += s.image.length;
        for (final e in s.data) {
          totalChars += e.data.length;
        }
      }
      final sample = vm.styles.take(4).map((s) => s.name).join(', ');
      setState(() {
        _visualManualProbeBody =
            'GET+POST styles=${vm.styles.length} · slots_data_chars_total=$totalChars · image_paths=$totalImages'
            '${sample.isEmpty ? '' : ' · sample: $sample'}';
        _loadingVisualManualProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingVisualManualProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingVisualManualProbe = false;
      });
    }
  }

  Future<void> _callDirectorManualProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingDirectorManualProbe = true;
      _error = null;
      _directorManualProbeBody = null;
    });
    try {
      final list = await postProjectQueryDirectorManual(token);
      if (!mounted) return;
      var slotChars = 0;
      var imagePaths = 0;
      for (final row in list.data) {
        imagePaths += row.image.length;
        for (final slot in row.data) {
          slotChars += slot.data.length;
        }
      }
      final sample = list.data
          .take(3)
          .map((r) => '${r.directorManual}:${r.name}')
          .join(', ');
      setState(() {
        _directorManualProbeBody =
            'folders=${list.data.length} · slot_data_chars=$slotChars · '
            'image_paths=$imagePaths'
            '${sample.isEmpty ? '' : ' · sample: $sample'}';
        _loadingDirectorManualProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDirectorManualProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDirectorManualProbe = false;
      });
    }
  }

  Future<void> _callSkillsBinaryProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillsBinaryProbe = true;
      _error = null;
      _skillsBinaryProbeBody = null;
    });
    try {
      const path = '_smoke/binary_probe.png';
      final bytes = await fetchSkillsBinaryV1(token, path);
      if (!mounted) return;
      final head = bytes.length >= 4 ? bytes.sublist(0, 4) : bytes;
      final magicOk =
          head.length == 4 &&
          head[0] == 0x89 &&
          head[1] == 0x50 &&
          head[2] == 0x4e &&
          head[3] == 0x47;
      setState(() {
        _skillsBinaryProbeBody =
            'path=$path · bytes=${bytes.length} · png_magic=$magicOk';
        _loadingSkillsBinaryProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsBinaryProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsBinaryProbe = false;
      });
    }
  }

  Future<void> _callModelsCatalog() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingModelsCatalog = true;
      _error = null;
      _modelsCatalogBody = null;
    });
    try {
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
      const productionBodies = <String, Map<String, dynamic>>{
        '/api/v1/production/assets/batch-generate-assets-image': {
          'projectId': 1,
          'scriptId': 1,
          'assetIds': [1],
        },
        '/api/v1/production/assets/delete-assets-derivative': {
          'projectId': 1,
          'assetIds': [1],
        },
        '/api/v1/production/assets/get-assets-data': {'projectId': 1},
        '/api/v1/production/assets/polling-image': {
          'projectId': 1,
          'assetIds': [1],
        },
        '/api/v1/production/assets/update-assets-url': {
          'projectId': 1,
          'assetId': 1,
          'imageUrl': 'https://example.com/probe.png',
        },
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
        final sample = list
            .take(4)
            .map((m) => '${m.value}(${m.type})')
            .join(', ');
        final modelsLine = list.isEmpty
            ? '(empty)'
            : '${list.length} models${sample.isEmpty ? '' : '; sample: $sample'}';
        final v0 = vs.vendors.isEmpty ? null : vs.vendors.first;
        final vendorsBit = v0 == null
            ? 'vendors: (empty)'
            : 'vendors: ${vs.vendors.length} · ${v0.name} kinds=${v0.modelKinds.join(",")} source=${vs.source}';
        final adBit =
            'agent-deploy: ${ad.length} rows · deploy-model->$deployM · set-key->$setKey · model-test -> $mt · script-agent/get-plan -> $sap · set-plan->$saSet · update->$saUpd · assets-gen -> $ag / polish->$agPol / batch->$agBat / batch-polish->$agBap · vendors/add -> $vadd · vend stubs -> $vUp/$vDel/$vEn/$vCode/$vLink · danger/delete-all -> $danger · clear-db -> $clearDb · production/get-data -> $prod · flow/save/workbench/poll/export -> $prFlow/$prSave/$prVid/$prPoll/$prExp · prod/implemented ${productionBodies.length}×(200/404/503)';
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

  Future<void> _callTextModelDefault() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingTextModelDefault = true;
      _error = null;
      _textModelDefaultBody = null;
    });
    try {
      final before = await fetchTextModelDefaultV1(token);
      final textModels = await fetchModelsCatalog(token, typeFilter: 'text');
      final alternative = textModels
          .map((m) => m.value)
          .where((id) => id != before.defaultModelId)
          .cast<String?>()
          .firstWhere((id) => id != null, orElse: () => null);
      TextModelDefaultV1? patched;
      if (alternative != null) {
        patched = await patchTextModelDefaultV1(token, modelId: alternative);
      }
      final reset = await patchTextModelDefaultV1(token, modelId: null);
      final after = await fetchTextModelDefaultV1(token);
      if (!mounted) return;
      if (patched != null && patched.defaultModelId != alternative) {
        setState(() {
          _error =
              'PATCH text-default expected $alternative, got ${patched!.defaultModelId}';
          _loadingTextModelDefault = false;
        });
        return;
      }
      if (after.defaultModelId != reset.defaultModelId) {
        setState(() {
          _error =
              'text-default reset mismatch: fetch=${after.defaultModelId} reset=${reset.defaultModelId}';
          _loadingTextModelDefault = false;
        });
        return;
      }
      setState(() {
        _textModelDefaultBody =
            'legacy=${before.legacyPlaceholder} · GET=${before.defaultModelId}'
            '${patched == null ? ' · PATCH skipped (single text model)' : ' · PATCH=$alternative'}'
            ' · reset=${reset.defaultModelId}';
        _loadingTextModelDefault = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTextModelDefault = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTextModelDefault = false;
      });
    }
  }

  Future<void> _callModelDetail() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingModelDetail = true;
      _error = null;
      _modelDetailBody = null;
    });
    try {
      final d = await fetchModelDetail(token, modelId: '1:gpt-4o-mini');
      if (!mounted) return;
      setState(() {
        _modelDetailBody =
            '${d.name} (${d.modelName}) type=${d.type} · vendor ${d.vendorName} [${d.vendorId}]';
        _loadingModelDetail = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingModelDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingModelDetail = false;
      });
    }
  }
}
