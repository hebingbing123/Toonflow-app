import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'home_page/sections.dart';
import 'rust_api.dart';

part 'home_page/editors.dart';

/// Script-agent REST hits Postgres; catalog probe allows 501 stub, 503 no pool, 404 missing project, or 200 OK.
bool _scriptAgentCatalogProbeOk(int status) =>
    status == 200 || status == 404 || status == 501 || status == 503;

/// **`assets-generate`** single + batch routes: **200** queued job, **404** project, **429** quota, **503** no DB.
bool _assetsGenerateSingleJobProbeOk(int status) =>
    status == 200 || status == 404 || status == 429 || status == 503;

/// **`settings/vendors/model-test`**: **200** queued job, **429** quota, **503** no DB.
bool _vendorModelTestProbeOk(int status) =>
    status == 200 || status == 429 || status == 503;

/// Legacy production probes: allow implemented **200**, placeholder **501**, or **503** when DB-gated routes run without pool.
bool _productionProbeOk(int status) =>
    status == 200 || status == 501 || status == 503;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  StreamSubscription<AuthState>? _authSub;
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;

  String? _healthBody;
  String? _healthRootBody;
  String? _pingBody;
  String? _versionBody;
  String? _readyBody;
  String? _meBody;
  String? _devSwitchProbeBody;
  String? _memoryConfigProbeBody;
  String? _aboutProbeBody;
  String? _usageSummaryBody;
  String? _promptsProbeBody;
  String? _visualManualProbeBody;
  String? _directorManualProbeBody;
  String? _skillsBinaryProbeBody;
  String? _modelsCatalogBody;
  String? _textModelDefaultBody;
  String? _modelDetailBody;
  String? _agentMemoryBody;
  String? _error;
  bool _loadingHealth = false;
  bool _loadingHealthRoot = false;
  bool _loadingPing = false;
  bool _loadingVersion = false;
  bool _loadingReady = false;
  bool _loadingMe = false;
  bool _loadingDevSwitchProbe = false;
  bool _loadingMemoryConfigProbe = false;
  bool _loadingAboutProbe = false;
  bool _loadingUsageSummary = false;
  bool _loadingPromptsProbe = false;
  bool _loadingVisualManualProbe = false;
  bool _loadingDirectorManualProbe = false;
  bool _loadingSkillsBinaryProbe = false;
  bool _loadingModelsCatalog = false;
  bool _loadingTextModelDefault = false;
  bool _loadingModelDetail = false;
  bool _loadingAgentMemory = false;
  bool _loadingWs = false;
  bool _loadingWsHarness = false;
  bool _loadingWsIsolatedEcho = false;
  bool _loadingWsHarnessAgent = false;
  bool _loadingWsSkillsRead = false;
  final List<String> _wsLog = [];

  bool _loadingProjects = false;
  bool _loadingProjectsSummary = false;
  bool _loadingArtStyles = false;
  bool _creatingProject = false;
  List<ProjectRow>? _projects;
  String? _projectsSummaryLine;
  String? _artStylesLine;

  bool _loadingJobs = false;
  bool _loadingJobKinds = false;
  bool _loadingJobKindSummary = false;
  bool _loadingJobStatusSummary = false;
  bool _creatingJob = false;
  String? _cancellingJobId;
  String? _retryingJobId;
  List<JobRow>? _jobs;
  String? _jobKindsLine;
  String? _jobKindSummaryLine;
  String? _jobStatusSummaryLine;
  bool _loadingJobById = false;
  String? _jobByIdLine;
  final _jobIdCtrl = TextEditingController();

  final _skillPathCtrl = TextEditingController(
    text: 'script_execution_script.md',
  );
  final _skillContentCtrl = TextEditingController(text: '# flutter probe\n');

  bool _loadingHarnessTools = false;
  bool _loadingSkillsSummary = false;
  bool _loadingSkillList = false;
  bool _loadingSkillPreview = false;
  bool _loadingSkillPut = false;
  bool _loadingSkillPost = false;
  bool _loadingSkillDelete = false;
  String? _harnessToolsLine;
  String? _skillsAggregateLine;
  String? _skillsListSummary;
  String? _skillMutationLine;

  @override
  void initState() {
    super.initState();
    if (kSupabaseConfigured) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _email.dispose();
    _password.dispose();
    _jobIdCtrl.dispose();
    _skillPathCtrl.dispose();
    _skillContentCtrl.dispose();
    super.dispose();
  }

  Session? get _session =>
      kSupabaseConfigured ? Supabase.instance.client.auth.currentSession : null;

  bool get _wsProbesBusy =>
      _loadingWs ||
      _loadingWsHarness ||
      _loadingWsIsolatedEcho ||
      _loadingWsHarnessAgent ||
      _loadingWsSkillsRead;

  void _appendWsLog(String raw) {
    const maxChars = 12000;
    final line = raw.length > maxChars
        ? '${raw.substring(0, maxChars)}… (+${raw.length - maxChars} chars)'
        : raw;
    if (!mounted) return;
    setState(() {
      _wsLog.insert(0, line);
      if (_wsLog.length > 16) _wsLog.removeLast();
    });
  }

  void _setErrorFromException(Object error) {
    if (!mounted) return;
    setState(() => _error = error.toString());
  }

  Future<void> _pingHealth() async {
    setState(() {
      _loadingHealth = true;
      _error = null;
      _healthBody = null;
    });
    try {
      final h = await fetchHealthV1();
      if (!mounted) return;
      setState(() {
        _healthBody = 'status=${h.status} service=${h.service}';
        _loadingHealth = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHealth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHealth = false;
      });
    }
  }

  Future<void> _pingHealthRoot() async {
    setState(() {
      _loadingHealthRoot = true;
      _error = null;
      _healthRootBody = null;
    });
    try {
      final h = await fetchHealthRoot();
      if (!mounted) return;
      setState(() {
        _healthRootBody = 'status=${h.status} service=${h.service}';
        _loadingHealthRoot = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHealthRoot = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHealthRoot = false;
      });
    }
  }

  Future<void> _pingPing() async {
    setState(() {
      _loadingPing = true;
      _error = null;
      _pingBody = null;
    });
    try {
      final p = await fetchPingV1();
      if (!mounted) return;
      setState(() {
        _pingBody = 'ok=${p.ok}';
        _loadingPing = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPing = false;
      });
    }
  }

  Future<void> _createEmptyProject() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _creatingProject = true;
      _error = null;
    });
    try {
      await createProject(token);
      if (!mounted) return;
      await _loadProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已创建项目')));
    } on RustApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creatingProject = false);
    }
  }

  Future<void> _pingVersion() async {
    setState(() {
      _loadingVersion = true;
      _error = null;
      _versionBody = null;
    });
    try {
      final v = await fetchVersionV1();
      if (!mounted) return;
      final parts = <String>['service=${v.service}', 'version=${v.version}'];
      if (v.gitSha != null && v.gitSha!.isNotEmpty) {
        parts.add('git_sha=${v.gitSha}');
      }
      setState(() {
        _versionBody = parts.join(' · ');
        _loadingVersion = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingVersion = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingVersion = false;
      });
    }
  }

  Future<void> _pingReady() async {
    setState(() {
      _loadingReady = true;
      _error = null;
      _readyBody = null;
    });
    try {
      final r = await fetchReadyV1();
      if (!mounted) return;
      setState(() {
        _readyBody = 'status=${r.status}, database=${r.database}';
        _loadingReady = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingReady = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingReady = false;
      });
    }
  }

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
      final putStatus = await putSwitchAiDevToolV1(token, '0');
      if (!mounted) return;
      if (putStatus != 501) {
        setState(() {
          _error = 'PUT switch-ai-tool expected 501, got $putStatus';
          _loadingDevSwitchProbe = false;
        });
        return;
      }
      setState(() {
        _devSwitchProbeBody =
            'GET value=${g.value} · PUT body {value:0} -> $putStatus not_implemented';
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
              'POST production/get-production-data expected 200/501/503, got $prod';
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
              'POST production/get-flow-data expected 200/501/503, got $prFlow';
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
              'POST production/save-flow-data expected 200/501/503, got $prSave';
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
              'POST production/workbench/generate-video expected 200/501/503, got $prVid';
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
              'POST production/storyboard/polling-image expected 200/501/503, got $prPoll';
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
              'POST production/export-image expected 200/501/503, got $prExp';
          _loadingModelsCatalog = false;
        });
        return;
      }
      // Keep in sync with `LEGACY_JSON_STUB_PATHS` in `backend/src/production_legacy.rs`.
      const productionLooseStubPaths = <String>[
        '/api/v1/production/assets/batch-generate-assets-image',
        '/api/v1/production/assets/delete-assets-derivative',
        '/api/v1/production/assets/get-assets-data',
        '/api/v1/production/assets/polling-image',
        '/api/v1/production/assets/update-assets-url',
        '/api/v1/production/edit-image/generate-flow-image',
        '/api/v1/production/edit-image/get-image-default-model',
        '/api/v1/production/edit-image/get-image-flow',
        '/api/v1/production/edit-image/save-image-flow',
        '/api/v1/production/edit-image/update-image-flow',
        '/api/v1/production/get-storyboard-data',
        '/api/v1/production/storyboard/add',
        '/api/v1/production/storyboard/batch-add-info',
        '/api/v1/production/storyboard/batch-generate-image',
        '/api/v1/production/storyboard/down-preview-image',
        '/api/v1/production/storyboard/edit-info',
        '/api/v1/production/storyboard/get-data',
        '/api/v1/production/storyboard/preview-image',
        '/api/v1/production/storyboard/remove-frame',
        '/api/v1/production/storyboard/update-url',
        '/api/v1/production/workbench/add-track',
        '/api/v1/production/workbench/delete-track',
        '/api/v1/production/workbench/delete-video',
        '/api/v1/production/workbench/generate-video-prompt',
        '/api/v1/production/workbench/get-generate-data',
        '/api/v1/production/workbench/get-video-list',
        '/api/v1/production/workbench/get-video-model-detail',
        '/api/v1/production/workbench/select-video',
      ];
      const prodPrefix = '/api/v1/production/';
      for (final path in productionLooseStubPaths) {
        final code = await postProductionLegacyJsonStubV1(token, path);
        if (!mounted) return;
        if (!_productionProbeOk(code)) {
          final rel = path.startsWith(prodPrefix)
              ? path.substring(prodPrefix.length)
              : path;
          setState(() {
            _error =
                'POST production/$rel loose stub expected 200/501/503, got $code';
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
            'agent-deploy: ${ad.length} rows · deploy-model->$deployM · set-key->$setKey · model-test -> $mt · script-agent/get-plan -> $sap · set-plan->$saSet · update->$saUpd · assets-gen -> $ag / polish->$agPol / batch->$agBat / batch-polish->$agBap · vendors/add -> $vadd · vend stubs -> $vUp/$vDel/$vEn/$vCode/$vLink · danger/delete-all -> $danger · clear-db -> $clearDb · production/get-data -> $prod · flow/save/workbench/poll/export -> $prFlow/$prSave/$prVid/$prPoll/$prExp · prod/loose ${productionLooseStubPaths.length}×(200/501/503)';
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
      final d = await fetchTextModelDefaultV1(token);
      if (!mounted) return;
      setState(() {
        _textModelDefaultBody =
            'legacy=${d.legacyPlaceholder} · default_model_id=${d.defaultModelId}';
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

  Future<void> _probeAgentMemory() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projects = _projects;
    if (projects == null || projects.isEmpty) {
      setState(
        () => _error =
            'Load projects first (agent memory needs a legacy project id).',
      );
      return;
    }
    final legacyId = projects.first.legacyId;
    setState(() {
      _loadingAgentMemory = true;
      _error = null;
      _agentMemoryBody = null;
    });
    try {
      final rows = await queryAgentMemory(
        token,
        projectId: legacyId,
        agentType: 'scriptAgent',
      );
      if (!mounted) return;
      var appendBit = '';
      try {
        final id = await appendAgentMemory(
          token,
          projectId: legacyId,
          agentType: 'scriptAgent',
          content: '[flutter probe] ${DateTime.now().toIso8601String()}',
        );
        final short = id.length > 8 ? '${id.substring(0, 8)}…' : id;
        appendBit = ' · append id=$short';
      } on RustApiException catch (e) {
        appendBit = ' · append -> ${e.statusCode}';
      }
      setState(() {
        _agentMemoryBody =
            '${rows.length} message(s) for project $legacyId$appendBit';
        _loadingAgentMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAgentMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAgentMemory = false;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _signUp() async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    _wsSub?.cancel();
    _ws?.sink.close();
    _ws = null;
    _wsSub = null;
    setState(() {
      _wsLog.clear();
      _projects = null;
      _creatingProject = false;
      _jobs = null;
      _jobByIdLine = null;
      _usageSummaryBody = null;
      _agentMemoryBody = null;
      _versionBody = null;
      _readyBody = null;
      _harnessToolsLine = null;
      _skillsAggregateLine = null;
      _skillsListSummary = null;
    });
  }

  Future<void> _loadHarnessTools() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingHarnessTools = true;
      _error = null;
      _harnessToolsLine = null;
    });
    try {
      final r = await fetchHarnessTools(token);
      if (!mounted) return;
      setState(() {
        _harnessToolsLine = r.tools
            .map((t) => '${t.name}: ${t.description}')
            .join('\n');
        _loadingHarnessTools = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHarnessTools = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHarnessTools = false;
      });
    }
  }

  Future<void> _loadSkillsAggregate() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillsSummary = true;
      _error = null;
      _skillsAggregateLine = null;
    });
    try {
      final s = await fetchSkillsSummary(token);
      if (!mounted) return;
      setState(() {
        _skillsAggregateLine =
            '${s.markdownFileCount} md files, ${s.totalBytes} bytes total';
        _loadingSkillsSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsSummary = false;
      });
    }
  }

  Future<void> _loadSkillList() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillList = true;
      _error = null;
      _skillsListSummary = null;
    });
    try {
      final list = await fetchSkills(token);
      if (!mounted) return;
      final sample = list.take(5).map((m) => m.path).join(', ');
      setState(() {
        _skillsListSummary =
            '${list.length} files; sample: ${sample.isEmpty ? '—' : sample}';
        _loadingSkillList = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillList = false;
      });
    }
  }

  Future<void> _previewSkillFile() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPreview = true;
      _error = null;
    });
    try {
      final r = await fetchSkillContent(token, path);
      if (!mounted) return;
      setState(() => _loadingSkillPreview = false);
      final text = r.content.length > 12000
          ? '${r.content.substring(0, 12000)}…\n\n(truncated)'
          : r.content;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(r.path),
          content: SingleChildScrollView(
            child: SelectableText(
              text,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPreview = false;
      });
    }
  }

  Future<void> _putSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPut = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      final r = await saveSkillContent(token, path, _skillContentCtrl.text);
      if (!mounted) return;
      setState(() {
        _loadingSkillPut = false;
        _skillMutationLine =
            'PUT 200: ${r.path} (${r.content.length} chars written)';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPut = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPut = false;
      });
    }
  }

  Future<void> _postSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPost = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      final r = await createSkillContent(token, path, _skillContentCtrl.text);
      if (!mounted) return;
      setState(() {
        _loadingSkillPost = false;
        _skillMutationLine =
            'POST 201: ${r.path} (${r.content.length} chars written)';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPost = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPost = false;
      });
    }
  }

  Future<void> _deleteSkillProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillDelete = true;
      _error = null;
      _skillMutationLine = null;
    });
    try {
      await deleteSkillContent(token, path);
      if (!mounted) return;
      setState(() {
        _loadingSkillDelete = false;
        _skillMutationLine = 'DELETE 204: $path';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillDelete = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillDelete = false;
      });
    }
  }

  Future<void> _loadJobs() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobs = true;
      _error = null;
      _jobs = null;
    });
    try {
      final list = await fetchJobs(token);
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loadingJobs = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    }
  }

  Future<void> _loadJobsKindFlutterProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobs = true;
      _error = null;
      _jobs = null;
    });
    try {
      final list = await fetchJobs(token, kind: 'flutter.probe');
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loadingJobs = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    }
  }

  Future<void> _loadJobsStatusFailed() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobs = true;
      _error = null;
      _jobs = null;
    });
    try {
      final list = await fetchJobs(token, status: 'failed');
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loadingJobs = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    }
  }

  Future<void> _loadJobsKindProbeStatusQueued() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobs = true;
      _error = null;
      _jobs = null;
    });
    try {
      final list = await fetchJobs(
        token,
        kind: 'flutter.probe',
        status: 'queued',
      );
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loadingJobs = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    }
  }

  Future<void> _loadJobKinds() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobKinds = true;
      _error = null;
      _jobKindsLine = null;
    });
    try {
      final kinds = await fetchJobKinds(token);
      if (!mounted) return;
      setState(() {
        _jobKindsLine = kinds.isEmpty ? '(empty)' : kinds.join(', ');
        _loadingJobKinds = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobKinds = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobKinds = false;
      });
    }
  }

  Future<void> _loadJobKindSummary() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobKindSummary = true;
      _error = null;
      _jobKindSummaryLine = null;
    });
    try {
      final rows = await fetchJobKindSummaries(token);
      if (!mounted) return;
      setState(() {
        _jobKindSummaryLine = rows.isEmpty
            ? '(empty)'
            : rows.map((r) => '${r.kind}: ${r.jobCount}').join(', ');
        _loadingJobKindSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobKindSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobKindSummary = false;
      });
    }
  }

  Future<void> _loadJobStatusSummary() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobStatusSummary = true;
      _error = null;
      _jobStatusSummaryLine = null;
    });
    try {
      final rows = await fetchJobStatusSummaries(token);
      if (!mounted) return;
      setState(() {
        _jobStatusSummaryLine = rows.isEmpty
            ? '(empty)'
            : rows.map((r) => '${r.status}: ${r.jobCount}').join(', ');
        _loadingJobStatusSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobStatusSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobStatusSummary = false;
      });
    }
  }

  Future<void> _fetchJobById() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final id = _jobIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _loadingJobById = true;
      _error = null;
      _jobByIdLine = null;
    });
    try {
      final j = await fetchJob(token, id);
      if (!mounted) return;
      setState(() {
        final parts = <String>[
          '${j.kind} · ${j.status}',
          'updated ${j.updatedAt}',
        ];
        if (j.claimedBy != null && j.claimedBy!.isNotEmpty) {
          parts.add('claimed_by=${j.claimedBy}');
        }
        _jobByIdLine = parts.join(' · ');
        _loadingJobById = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobById = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobById = false;
      });
    }
  }

  Future<void> _cancelQueuedJob(JobRow j) async {
    final token = _session?.accessToken;
    if (token == null || (j.status != 'queued' && j.status != 'running')) {
      return;
    }
    setState(() {
      _cancellingJobId = j.id;
      _error = null;
    });
    try {
      await cancelJob(token, j.id);
      if (!mounted) return;
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _cancellingJobId = null);
      }
    }
  }

  Future<void> _retryFailedJob(JobRow j) async {
    final token = _session?.accessToken;
    if (token == null || j.status != 'failed') return;
    setState(() {
      _retryingJobId = j.id;
      _error = null;
    });
    try {
      await retryJob(token, j.id);
      if (!mounted) return;
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _retryingJobId = null);
      }
    }
  }

  Future<void> _createProbeJob() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _creatingJob = true;
      _error = null;
    });
    try {
      final key = 'flutter-probe-idem-${DateTime.now().millisecondsSinceEpoch}';
      final j1 = await createJob(token, 'flutter.probe', idempotencyKey: key);
      final j2 = await createJob(token, 'flutter.probe', idempotencyKey: key);
      if (!mounted) return;
      if (j1.id != j2.id) {
        setState(() {
          _error =
              'POST /api/v1/jobs idempotency: expected same id, got '
              '${j1.id} vs ${j2.id}';
          _creatingJob = false;
        });
        return;
      }
      setState(() => _creatingJob = false);
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creatingJob = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creatingJob = false;
      });
    }
  }

  Future<void> _loadProjects() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingProjects = true;
      _error = null;
      _projects = null;
    });
    try {
      final list = await fetchProjects(token);
      if (!mounted) return;
      setState(() {
        _projects = list;
        _loadingProjects = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjects = false;
      });
    }
  }

  Future<void> _loadProjectsSummary() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingProjectsSummary = true;
      _error = null;
      _projectsSummaryLine = null;
    });
    try {
      final s = await fetchProjectsSummary(token);
      if (!mounted) return;
      setState(() {
        _projectsSummaryLine =
            'projects=${s.projectCount} scripts=${s.scriptCount} storyboards=${s.storyboardCount} novels=${s.novelCount} roles=${s.roleCount} art_styles=${s.artStyleCount} assets=${s.assetCount} videos=${s.videoCount}';
        _loadingProjectsSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjectsSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjectsSummary = false;
      });
    }
  }

  Future<void> _loadArtStyles() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingArtStyles = true;
      _error = null;
      _artStylesLine = null;
    });
    try {
      final r = await fetchArtStyles(token);
      if (!mounted) return;
      var line =
          'total=${r.total} · ${r.items.take(5).map((s) => '#${s.legacyId}:${s.name}').join(', ')}${r.items.length > 5 ? '…' : ''}';
      try {
        final probeName =
            '[flutter probe art-style] ${DateTime.now().toIso8601String()}';
        final created = await createArtStyle(token, name: probeName);
        await fetchArtStyleByLegacyId(token, legacyId: created.legacyId);
        await patchArtStyleByLegacyId(
          token,
          created.legacyId,
          <String, dynamic>{'label': 'probe'},
        );
        await deleteArtStyleByLegacyId(token, created.legacyId);
        line += ' · create→get→patch→del ok (#${created.legacyId})';
      } on RustApiException catch (e) {
        line += ' · crud -> ${e.statusCode}';
      }
      setState(() {
        _artStylesLine = line;
        _loadingArtStyles = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingArtStyles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingArtStyles = false;
      });
    }
  }

  Future<void> _testWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWs = true;
      _wsLog.clear();
      _error = null;
    });

    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _ws = channel;

      _wsSub = channel.stream.listen(
        (message) => _appendWsLog(message.toString()),
        onError: (Object e) {
          if (mounted) setState(() => _error = 'ws: $e');
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

      channel.sink.add(
        jsonEncode({
          'type': 'agent.script.attach',
          'schema_version': 1,
          'payload': {'isolation_key': 'flutter-dev', 'project_id': 1},
        }),
      );

      channel.sink.add(
        jsonEncode({
          'type': 'agent.chat.send',
          'schema_version': 1,
          'payload': {'content': 'hello from Flutter'},
        }),
      );

      if (mounted) setState(() => _loadingWs = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWs = false;
        });
      }
    }
  }

  Future<void> _testHarnessToolWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWsHarness = true;
      _wsLog.clear();
      _error = null;
    });

    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _ws = channel;

      _wsSub = channel.stream.listen(
        (message) => _appendWsLog(message.toString()),
        onError: (Object e) {
          if (mounted) setState(() => _error = 'ws: $e');
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

      channel.sink.add(
        jsonEncode({
          'type': 'harness.tool.invoke',
          'schema_version': 1,
          'payload': {
            'name': 'echo',
            'arguments': {
              'source': 'flutter',
              'probe': 'harness.tool.invoke',
              'at': DateTime.now().toUtc().toIso8601String(),
            },
          },
        }),
      );

      if (mounted) setState(() => _loadingWsHarness = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWsHarness = false;
        });
      }
    }
  }

  Future<void> _testHarnessIsolatedEchoWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWsIsolatedEcho = true;
      _wsLog.clear();
      _error = null;
    });

    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _ws = channel;

      _wsSub = channel.stream.listen(
        (message) => _appendWsLog(message.toString()),
        onError: (Object e) {
          if (mounted) setState(() => _error = 'ws: $e');
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

      channel.sink.add(
        jsonEncode({
          'type': 'harness.tool.invoke',
          'schema_version': 1,
          'payload': {
            'name': 'isolated.echo',
            'arguments': {
              'source': 'flutter',
              'probe': 'harness.tool.invoke (isolated)',
              'at': DateTime.now().toUtc().toIso8601String(),
            },
          },
        }),
      );

      if (mounted) setState(() => _loadingWsIsolatedEcho = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWsIsolatedEcho = false;
        });
      }
    }
  }

  Future<void> _testHarnessSkillsReadWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWsSkillsRead = true;
      _wsLog.clear();
      _error = null;
    });

    final path = _skillPathCtrl.text.trim().isEmpty
        ? 'script_execution_script.md'
        : _skillPathCtrl.text.trim();

    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _ws = channel;

      _wsSub = channel.stream.listen(
        (message) => _appendWsLog(message.toString()),
        onError: (Object e) {
          if (mounted) setState(() => _error = 'ws: $e');
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

      channel.sink.add(
        jsonEncode({
          'type': 'harness.tool.invoke',
          'schema_version': 1,
          'payload': {
            'name': 'skills.read',
            'arguments': {'path': path},
          },
        }),
      );

      if (mounted) setState(() => _loadingWsSkillsRead = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWsSkillsRead = false;
        });
      }
    }
  }

  Future<void> _testHarnessAgentRunWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWsHarnessAgent = true;
      _wsLog.clear();
      _error = null;
    });

    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _ws = channel;

      _wsSub = channel.stream.listen(
        (message) => _appendWsLog(message.toString()),
        onError: (Object e) {
          if (mounted) setState(() => _error = 'ws: $e');
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _loadingWs = false;
              _loadingWsHarness = false;
              _loadingWsIsolatedEcho = false;
              _loadingWsHarnessAgent = false;
              _loadingWsSkillsRead = false;
            });
          }
        },
      );

      channel.sink.add(
        jsonEncode({
          'type': 'agent.script.attach',
          'schema_version': 1,
          'payload': {
            'isolation_key': 'flutter-harness-agent',
            'project_id': 1,
          },
        }),
      );

      channel.sink.add(
        jsonEncode({
          'type': 'harness.agent.run',
          'schema_version': 1,
          'payload': {
            'content':
                'Call the wasm.probe tool once with empty object arguments. Reply with only the numeric value from the tool result.',
            'max_tool_rounds': 6,
          },
        }),
      );

      if (mounted) setState(() => _loadingWsHarnessAgent = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWsHarnessAgent = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final signedIn = session != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Toonflow')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          OverviewSection(
            apiBaseUrl: kApiBaseUrl,
            loadingHealth: _loadingHealth,
            loadingHealthRoot: _loadingHealthRoot,
            loadingPing: _loadingPing,
            loadingVersion: _loadingVersion,
            loadingReady: _loadingReady,
            healthBody: _healthBody,
            healthRootBody: _healthRootBody,
            pingBody: _pingBody,
            versionBody: _versionBody,
            readyBody: _readyBody,
            onPingHealth: _pingHealth,
            onPingHealthRoot: _pingHealthRoot,
            onPingPing: _pingPing,
            onPingVersion: _pingVersion,
            onPingReady: _pingReady,
          ),
          AuthSection(
            signedIn: signedIn,
            session: session,
            emailController: _email,
            passwordController: _password,
            loadingMe: _loadingMe,
            loadingDevSwitchProbe: _loadingDevSwitchProbe,
            loadingMemoryConfigProbe: _loadingMemoryConfigProbe,
            loadingAboutProbe: _loadingAboutProbe,
            loadingUsageSummary: _loadingUsageSummary,
            loadingPromptsProbe: _loadingPromptsProbe,
            loadingVisualManualProbe: _loadingVisualManualProbe,
            loadingDirectorManualProbe: _loadingDirectorManualProbe,
            loadingSkillsBinaryProbe: _loadingSkillsBinaryProbe,
            loadingModelsCatalog: _loadingModelsCatalog,
            loadingTextModelDefault: _loadingTextModelDefault,
            loadingModelDetail: _loadingModelDetail,
            meBody: _meBody,
            devSwitchProbeBody: _devSwitchProbeBody,
            memoryConfigProbeBody: _memoryConfigProbeBody,
            aboutProbeBody: _aboutProbeBody,
            usageSummaryBody: _usageSummaryBody,
            promptsProbeBody: _promptsProbeBody,
            visualManualProbeBody: _visualManualProbeBody,
            directorManualProbeBody: _directorManualProbeBody,
            skillsBinaryProbeBody: _skillsBinaryProbeBody,
            modelsCatalogBody: _modelsCatalogBody,
            textModelDefaultBody: _textModelDefaultBody,
            modelDetailBody: _modelDetailBody,
            onSignIn: _signIn,
            onSignUp: _signUp,
            onSignOut: _signOut,
            onCallMe: _callMe,
            onCallDevSwitchProbe: _callDevSwitchProbe,
            onCallMemoryConfigProbe: _callMemoryConfigProbe,
            onCallAboutProbe: _callAboutProbe,
            onCallUsageSummary: _callUsageSummary,
            onCallPromptsProbe: _callPromptsProbe,
            onCallVisualManualProbe: _callVisualManualProbe,
            onCallDirectorManualProbe: _callDirectorManualProbe,
            onCallSkillsBinaryProbe: _callSkillsBinaryProbe,
            onCallModelsCatalog: _callModelsCatalog,
            onCallTextModelDefault: _callTextModelDefault,
            onCallModelDetail: _callModelDetail,
          ),
          if (signedIn) ...[
            ProjectsSection(
              loadingProjects: _loadingProjects,
              loadingProjectsSummary: _loadingProjectsSummary,
              loadingArtStyles: _loadingArtStyles,
              creatingProject: _creatingProject,
              loadingAgentMemory: _loadingAgentMemory,
              projects: _projects,
              projectsSummaryLine: _projectsSummaryLine,
              artStylesLine: _artStylesLine,
              agentMemoryBody: _agentMemoryBody,
              onLoadProjects: _loadProjects,
              onLoadProjectsSummary: _loadProjectsSummary,
              onLoadArtStyles: _loadArtStyles,
              onCreateEmptyProject: _createEmptyProject,
              onOpenProjectDetail: _openProjectDetail,
              onProbeAgentMemory: _probeAgentMemory,
            ),
            JobsSection(
              loadingJobs: _loadingJobs,
              loadingJobKinds: _loadingJobKinds,
              loadingJobKindSummary: _loadingJobKindSummary,
              loadingJobStatusSummary: _loadingJobStatusSummary,
              creatingJob: _creatingJob,
              loadingJobById: _loadingJobById,
              jobIdController: _jobIdCtrl,
              jobs: _jobs,
              jobByIdLine: _jobByIdLine,
              jobKindsLine: _jobKindsLine,
              jobKindSummaryLine: _jobKindSummaryLine,
              jobStatusSummaryLine: _jobStatusSummaryLine,
              cancellingJobId: _cancellingJobId,
              retryingJobId: _retryingJobId,
              onJobIdChanged: (_) => setState(() {}),
              onLoadJobs: _loadJobs,
              onLoadJobsKindFlutterProbe: _loadJobsKindFlutterProbe,
              onLoadJobsStatusFailed: _loadJobsStatusFailed,
              onLoadJobsKindProbeStatusQueued: _loadJobsKindProbeStatusQueued,
              onLoadJobKinds: _loadJobKinds,
              onLoadJobKindSummary: _loadJobKindSummary,
              onLoadJobStatusSummary: _loadJobStatusSummary,
              onCreateProbeJob: _createProbeJob,
              onFetchJobById: _fetchJobById,
              onSelectJob: (job) => setState(() => _jobIdCtrl.text = job.id),
              onRetryFailedJob: _retryFailedJob,
              onCancelQueuedJob: _cancelQueuedJob,
            ),
            HarnessSection(
              loadingHarnessTools: _loadingHarnessTools,
              loadingSkillsSummary: _loadingSkillsSummary,
              loadingSkillList: _loadingSkillList,
              loadingSkillPreview: _loadingSkillPreview,
              loadingSkillPut: _loadingSkillPut,
              loadingSkillPost: _loadingSkillPost,
              loadingSkillDelete: _loadingSkillDelete,
              wsProbesBusy: _wsProbesBusy,
              loadingWs: _loadingWs,
              loadingWsHarness: _loadingWsHarness,
              loadingWsIsolatedEcho: _loadingWsIsolatedEcho,
              loadingWsSkillsRead: _loadingWsSkillsRead,
              loadingWsHarnessAgent: _loadingWsHarnessAgent,
              harnessToolsLine: _harnessToolsLine,
              skillsAggregateLine: _skillsAggregateLine,
              skillsListSummary: _skillsListSummary,
              skillMutationLine: _skillMutationLine,
              skillPathController: _skillPathCtrl,
              skillContentController: _skillContentCtrl,
              wsLog: _wsLog,
              onLoadHarnessTools: _loadHarnessTools,
              onLoadSkillsAggregate: _loadSkillsAggregate,
              onLoadSkillList: _loadSkillList,
              onPreviewSkillFile: _previewSkillFile,
              onPutSkillProbe: _putSkillProbe,
              onPostSkillProbe: _postSkillProbe,
              onDeleteSkillProbe: _deleteSkillProbe,
              onTestWebSocket: _testWebSocket,
              onTestHarnessToolWebSocket: _testHarnessToolWebSocket,
              onTestHarnessIsolatedEchoWebSocket:
                  _testHarnessIsolatedEchoWebSocket,
              onTestHarnessSkillsReadWebSocket: _testHarnessSkillsReadWebSocket,
              onTestHarnessAgentRunWebSocket: _testHarnessAgentRunWebSocket,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              '错误: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
