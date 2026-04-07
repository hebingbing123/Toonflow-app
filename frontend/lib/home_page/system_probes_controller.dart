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
