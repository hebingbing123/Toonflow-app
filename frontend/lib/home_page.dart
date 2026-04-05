import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'rust_api.dart';

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
  String? _usageSummaryBody;
  String? _promptsProbeBody;
  String? _visualManualProbeBody;
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
  bool _loadingUsageSummary = false;
  bool _loadingPromptsProbe = false;
  bool _loadingVisualManualProbe = false;
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

  final _skillPathCtrl =
      TextEditingController(text: 'script_execution_script.md');
  final _skillContentCtrl =
      TextEditingController(text: '# flutter probe\n');

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已创建项目')),
      );
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
      final parts = <String>[
        'service=${v.service}',
        'version=${v.version}',
      ];
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
      final parts = <String>[
        'sub=${r.sub}',
        'plan_tier=${r.planTier}',
      ];
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
      setState(() {
        _promptsProbeBody =
            'count=${rows.length} · types=$types · data_chars_total=$totalChars';
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
      if (!mounted) return;
      var totalChars = 0;
      var totalImages = 0;
      for (final s in vm.styles) {
        totalImages += s.image.length;
        for (final e in s.data) {
          totalChars += e.data.length;
        }
      }
      final sample =
          vm.styles.take(4).map((s) => s.name).join(', ');
      setState(() {
        _visualManualProbeBody =
            'styles=${vm.styles.length} · slots_data_chars_total=$totalChars · image_paths=$totalImages'
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
      final magicOk = head.length == 4 &&
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
      if (!mounted) return;
      setState(() {
        final sample = list
            .take(4)
            .map((m) => '${m.value}(${m.type})')
            .join(', ');
        _modelsCatalogBody = list.isEmpty
            ? '(empty)'
            : '${list.length} models${sample.isEmpty ? '' : '; sample: $sample'}';
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
      setState(() => _error = 'Load projects first (agent memory needs a legacy project id).');
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
      setState(() {
        _agentMemoryBody = '${rows.length} message(s) for project $legacyId';
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
            child: SelectableText(text, style: Theme.of(ctx).textTheme.bodySmall),
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
      await createJob(token, 'flutter.probe');
      if (!mounted) return;
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
      setState(() {
        _artStylesLine =
            'total=${r.total} · ${r.items.take(5).map((s) => '#${s.legacyId}:${s.name}').join(', ')}${r.items.length > 5 ? '…' : ''}';
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

  Future<void> _openProjectDetail(ProjectRow p) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final nameCtrl = TextEditingController(text: p.name ?? '');
    final introCtrl = TextEditingController(text: p.intro ?? '');
    try {
      final detail = await fetchProjectByLegacyId(token, p.legacyId);
      if (!mounted) return;
      nameCtrl.text = detail.project.name ?? '';
      introCtrl.text = detail.project.intro ?? '';
      final scriptList = List<ScriptBrief>.from(detail.scripts);
      ProjectStats? statsSnap;
      try {
        statsSnap = await fetchProjectStatsByLegacyId(token, p.legacyId);
      } catch (_) {
        statsSnap = null;
      }
      ListAssetsResponse? assetsSnap;
      try {
        assetsSnap = await fetchProjectAssetsByLegacyId(token, p.legacyId);
      } catch (_) {
        assetsSnap = null;
      }
      ListNovelsResponse? novelsSnap;
      try {
        novelsSnap = await fetchProjectNovelsByLegacyId(token, p.legacyId);
      } catch (_) {
        novelsSnap = null;
      }
      if (!mounted) return;
      final statsRef = <ProjectStats?>[statsSnap];
      final assetsRef = <ListAssetsResponse?>[assetsSnap];
      final novelsRef = <ListNovelsResponse?>[novelsSnap];
      final assetsForScriptRef = <ListAssetsResponse?>[null];
      final assetsFilterScriptLegacyId = <int?>[null];
      final assetsLoading = <bool>[false];
      final assetsScriptFilterLoading = <bool>[false];
      final assetsBusy = <bool>[false];
      final novelsLoading = <bool>[false];
      final novelsBusy = <bool>[false];
      final scriptProbeBusy = <bool>[false];
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              Future<void> reloadAssetsAndStats() async {
                try {
                  assetsRef[0] = await fetchProjectAssetsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {
                  assetsRef[0] = null;
                }
                final sid = assetsFilterScriptLegacyId[0];
                if (sid != null) {
                  try {
                    assetsForScriptRef[0] = await fetchProjectAssetsByLegacyId(
                      token,
                      p.legacyId,
                      scriptLegacyId: sid,
                    );
                  } catch (_) {
                    assetsForScriptRef[0] = null;
                  }
                }
                try {
                  statsRef[0] = await fetchProjectStatsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {}
                try {
                  novelsRef[0] = await fetchProjectNovelsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {
                  novelsRef[0] = null;
                }
                if (ctx.mounted) {
                  setDialogState(() {});
                }
              }

              return AlertDialog(
                title: Text(
                  detail.project.name ?? 'legacy #${detail.project.legacyId}',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: introCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Intro (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (statsRef[0] != null)
                        Text(
                          'GET …/stats：剧本 ${statsRef[0]!.scriptCount} · 分镜 '
                          '${statsRef[0]!.storyboardCount} · 小说 ${statsRef[0]!.novelCount} · 角色/视频 '
                          '${statsRef[0]!.roleCount}/${statsRef[0]!.videoCount}（视频占位）',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        )
                      else
                        Text(
                          'GET …/stats 未加载',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.outline,
                              ),
                        ),
                      const SizedBox(height: 12),
                      if (novelsRef[0] != null)
                        Text(
                          novelsRef[0]!.items.isEmpty
                              ? 'GET …/novels：total=0'
                              : 'GET …/novels：total=${novelsRef[0]!.total} · ${novelsRef[0]!.items.take(4).map((n) => '#${n.legacyId}:${n.chapter}').join(', ')}${novelsRef[0]!.items.length > 4 ? '…' : ''}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        )
                      else
                        Text(
                          'GET …/novels 未加载',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.outline,
                              ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: novelsLoading[0] ||
                                  assetsBusy[0] ||
                                  assetsLoading[0] ||
                                  assetsScriptFilterLoading[0]
                              ? null
                              : () async {
                                  setDialogState(() => novelsLoading[0] = true);
                                  try {
                                    await reloadAssetsAndStats();
                                  } finally {
                                    if (ctx.mounted) {
                                      setDialogState(
                                        () => novelsLoading[0] = false,
                                      );
                                    }
                                  }
                                },
                          child: Text(
                            novelsLoading[0]
                                ? '刷新小说…'
                                : '刷新小说列表',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          TextButton(
                            onPressed: novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      final ts = DateTime.now()
                                          .millisecondsSinceEpoch;
                                      await createProjectNovelUnderLegacy(
                                        token,
                                        p.legacyId,
                                        chapter: 'novel_probe_$ts',
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 POST 测试章节'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => novelsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('POST 测试章节'),
                          ),
                          TextButton(
                            onPressed: novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    novelsRef[0] == null ||
                                    novelsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    final first = novelsRef[0]!.items.first;
                                    try {
                                      final row =
                                          await fetchProjectNovelByLegacyIds(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/novels/${first.legacyId}：'
                                            '${row.chapter}',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => novelsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('GET 首条小说'),
                          ),
                          TextButton(
                            onPressed: novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      final pg =
                                          await fetchProjectNovelsByLegacyId(
                                        token,
                                        p.legacyId,
                                        search: 'novel',
                                        page: 1,
                                        limit: 5,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/novels?search=novel&page=1&limit=5：'
                                            'total=${pg.total}，本页 ${pg.items.length} 条',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => novelsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('GET 小说 search+分页'),
                          ),
                          TextButton(
                            onPressed: novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    novelsRef[0] == null ||
                                    novelsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    final first = novelsRef[0]!.items.first;
                                    try {
                                      await patchProjectNovelByLegacyIds(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                        {
                                          'chapter': '${first.chapter}·patched',
                                        },
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 PATCH 首条小说 chapter'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => novelsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('PATCH 首条小说'),
                          ),
                          TextButton(
                            onPressed: novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    novelsRef[0] == null ||
                                    novelsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    final last = novelsRef[0]!.items.last;
                                    try {
                                      await deleteProjectNovelByLegacyIds(
                                        token,
                                        p.legacyId,
                                        last.legacyId,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '已 DELETE 末条小说 #${last.legacyId}',
                                            ),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => novelsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('DELETE 末条小说'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (assetsRef[0] != null)
                        Text(
                          assetsRef[0]!.items.isEmpty
                              ? 'GET …/assets：total=0'
                              : 'GET …/assets：total=${assetsRef[0]!.total} · ${assetsRef[0]!.items.take(6).map((a) => '#${a.legacyId}:${a.assetType}').join(', ')}${assetsRef[0]!.items.length > 6 ? '…' : ''}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        )
                      else
                        Text(
                          'GET …/assets 未加载',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.outline,
                              ),
                        ),
                      if (assetsFilterScriptLegacyId[0] != null) ...[
                        const SizedBox(height: 6),
                        if (assetsScriptFilterLoading[0])
                          Text(
                            'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]} …',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(ctx).colorScheme.outline,
                                ),
                          )
                        else if (assetsForScriptRef[0] != null)
                          Text(
                            assetsForScriptRef[0]!.items.isEmpty
                                ? 'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]}：total=0'
                                : 'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]}：total=${assetsForScriptRef[0]!.total} · ${assetsForScriptRef[0]!.items.take(6).map((a) => '#${a.legacyId}:${a.assetType}').join(', ')}${assetsForScriptRef[0]!.items.length > 6 ? '…' : ''}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          )
                        else
                          Text(
                            'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]} 未加载',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(ctx).colorScheme.outline,
                                ),
                          ),
                      ],
                      if (scriptList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DropdownButton<int?>(
                            value: assetsFilterScriptLegacyId[0],
                            isExpanded: true,
                            hint: const Text('按剧本筛选资产列表'),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('（全部，不按剧本筛选）'),
                              ),
                              ...scriptList.map(
                                (s) => DropdownMenuItem<int?>(
                                  value: s.legacyId,
                                  child: Text(
                                    '#${s.legacyId} ${s.name ?? ""}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : (v) async {
                                    setDialogState(
                                      () => assetsScriptFilterLoading[0] = true,
                                    );
                                    assetsFilterScriptLegacyId[0] = v;
                                    if (v == null) {
                                      assetsForScriptRef[0] = null;
                                    }
                                    try {
                                      await reloadAssetsAndStats();
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => assetsScriptFilterLoading[0] =
                                              false,
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: assetsLoading[0] ||
                                  assetsScriptFilterLoading[0]
                              ? null
                              : () async {
                                  setDialogState(() => assetsLoading[0] = true);
                                  try {
                                    await reloadAssetsAndStats();
                                  } finally {
                                    if (ctx.mounted) {
                                      setDialogState(
                                        () => assetsLoading[0] = false,
                                      );
                                    }
                                  }
                                },
                          child: Text(
                            assetsLoading[0]
                                ? '刷新资产…'
                                : '刷新资产列表',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    try {
                                      final r =
                                          await fetchCornerScapeAssetsByLegacyId(
                                        token,
                                        p.legacyId,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/assets/corner-scape：'
                                            '${r.items.length} 条',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('POST corner-scape'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final first = assetsRef[0]!.items.first;
                                    try {
                                      final ts = DateTime.now()
                                          .millisecondsSinceEpoch;
                                      final row = await createProjectAssetImage(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                        filePath: 'probe/hist_$ts.png',
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/assets/${first.legacyId}/images：'
                                            '${row.id.substring(0, 8)}…',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('POST 首条资产图片'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    try {
                                      final ts = DateTime.now()
                                          .millisecondsSinceEpoch;
                                      await createProjectAssetUnderLegacy(
                                        token,
                                        p.legacyId,
                                        name: 'role_probe_$ts',
                                        type: 'role',
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 POST 测试资产'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('POST 测试资产'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final first = assetsRef[0]!.items.first;
                                    try {
                                      final row = await fetchProjectAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/assets/${first.legacyId}：'
                                            '${row.name} (${row.assetType})',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('GET 首条资产详情'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    try {
                                      final page = await fetchProjectAssetsByLegacyId(
                                        token,
                                        p.legacyId,
                                        page: 1,
                                        limit: 2,
                                      );
                                      if (!ctx.mounted) return;
                                      final ids = page.items
                                          .map((a) => '#${a.legacyId}:${a.assetType}')
                                          .join(', ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/assets?page=1&limit=2：'
                                            'total=${page.total}，本页 ${page.items.length} 条'
                                            '${ids.isEmpty ? '' : ' · $ids'}',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('GET 分页 page=1&limit=2'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    try {
                                      final r = await fetchProjectAssetsByLegacyId(
                                        token,
                                        p.legacyId,
                                        assetType: 'role',
                                        name: 'probe',
                                      );
                                      if (!ctx.mounted) return;
                                      final ids = r.items
                                          .take(4)
                                          .map((a) => '#${a.legacyId}:${a.name}')
                                          .join(', ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/assets?asset_type=role&name=probe：'
                                            'total=${r.total}，返回 ${r.items.length} 条'
                                            '${ids.isEmpty ? '' : ' · $ids'}',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('GET 筛选 type+name'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsFilterScriptLegacyId[0] == null
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final sid = assetsFilterScriptLegacyId[0]!;
                                    try {
                                      final pg = await fetchProjectAssetsByLegacyId(
                                        token,
                                        p.legacyId,
                                        scriptLegacyId: sid,
                                        page: 1,
                                        limit: 2,
                                      );
                                      if (!ctx.mounted) return;
                                      final ids = pg.items
                                          .map((a) => '#${a.legacyId}:${a.assetType}')
                                          .join(', ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/assets?script_legacy_id=$sid'
                                            '&page=1&limit=2：total=${pg.total}，'
                                            '本页 ${pg.items.length} 条'
                                            '${ids.isEmpty ? '' : ' · $ids'}',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('GET 当前剧本+分页'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final first = assetsRef[0]!.items.first;
                                    try {
                                      await patchProjectAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                        {'name': '${first.name}·patched'},
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 PATCH 首条资产名称'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('PATCH 首条'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final last = assetsRef[0]!.items.last;
                                    try {
                                      await deleteProjectAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        last.legacyId,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '已 DELETE 资产 #${last.legacyId}',
                                            ),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('DELETE 末条'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    scriptList.isEmpty ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final sid = scriptList.first.legacyId;
                                    final aid = assetsRef[0]!.items.first.legacyId;
                                    try {
                                      await linkScriptToAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        sid,
                                        aid,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '已 PUT 关联 script#$sid · asset#$aid',
                                            ),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('PUT 关联首剧本·首资产'),
                          ),
                          TextButton(
                            onPressed: assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    scriptList.isEmpty ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final sid = scriptList.first.legacyId;
                                    final aid = assetsRef[0]!.items.first.legacyId;
                                    try {
                                      await unlinkScriptFromAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        sid,
                                        aid,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 DELETE 剧本–资产关联'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => assetsBusy[0] = false);
                                      }
                                    }
                                  },
                            child: const Text('DELETE 取消关联'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('${scriptList.length} script(s)'),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          TextButton(
                            onPressed: scriptProbeBusy[0] ||
                                    scriptList.isEmpty ||
                                    saving[0]
                                ? null
                                : () async {
                                    setDialogState(() => scriptProbeBusy[0] = true);
                                    try {
                                      final ids = scriptList
                                          .map((s) => s.legacyId)
                                          .toList();
                                      final zip = await exportScriptsZip(
                                        token,
                                        ids,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/scripts/export：${zip.length} bytes · '
                                            '${ids.length} legacy id(s)',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              scriptProbeBusy[0]
                                  ? 'export…'
                                  : 'POST scripts/export (ZIP)',
                            ),
                          ),
                          TextButton(
                            onPressed: scriptProbeBusy[0] ||
                                    scriptList.isEmpty ||
                                    saving[0]
                                ? null
                                : () async {
                                    setDialogState(() => scriptProbeBusy[0] = true);
                                    try {
                                      final ids = scriptList
                                          .map((s) => s.legacyId)
                                          .toList();
                                      final rows = await pollScriptExtractState(
                                        token,
                                        ids,
                                      );
                                      if (!ctx.mounted) return;
                                      final sample = rows.isEmpty
                                          ? '（empty：均在提取中或 idle）'
                                          : rows
                                              .take(3)
                                              .map(
                                                (r) =>
                                                    '#${r.legacyId} state=${r.extractState}',
                                              )
                                              .join('; ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/extract-state/poll：${rows.length} row(s) $sample',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              scriptProbeBusy[0]
                                  ? 'poll…'
                                  : 'POST extract-state/poll',
                            ),
                          ),
                          TextButton(
                            onPressed: scriptProbeBusy[0] ||
                                    scriptList.isEmpty ||
                                    saving[0]
                                ? null
                                : () async {
                                    setDialogState(() => scriptProbeBusy[0] = true);
                                    try {
                                      final ids = scriptList
                                          .map((s) => s.legacyId)
                                          .toList();
                                      final acc = await startScriptAssetExtract(
                                        token,
                                        projectLegacyId: p.legacyId,
                                        scriptLegacyIds: ids,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/extract-assets：${acc.status} — ${acc.message}',
                                          ),
                                        ),
                                      );
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              scriptProbeBusy[0]
                                  ? 'extract…'
                                  : 'POST extract-assets',
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: saving[0]
                              ? null
                              : () async {
                                  setDialogState(() => saving[0] = true);
                                  try {
                                    final s =
                                        await createScriptUnderProjectLegacy(
                                      token,
                                      p.legacyId,
                                    );
                                    if (!ctx.mounted) return;
                                    scriptList.add(
                                      ScriptBrief(
                                        legacyId: s.legacyId,
                                        name: s.name,
                                        extractState: s.extractState,
                                      ),
                                    );
                                    try {
                                      statsRef[0] =
                                          await fetchProjectStatsByLegacyId(
                                        token,
                                        p.legacyId,
                                      );
                                    } catch (_) {}
                                    if (!ctx.mounted) return;
                                    setDialogState(() => saving[0] = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '已创建剧本 legacy #${s.legacyId}',
                                        ),
                                      ),
                                    );
                                  } on RustApiException catch (e) {
                                    if (ctx.mounted) {
                                      setDialogState(() => saving[0] = false);
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setDialogState(() => saving[0] = false);
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                          child: const Text('POST 空剧本'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...scriptList.map(
                        (s) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '#${s.legacyId} ${s.name ?? ""}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: saving[0]
                              ? null
                              : () => _openScriptEditor(
                                    token,
                                    s.legacyId,
                                    onScriptTreeMutated: () async {
                                      final d = await fetchProjectByLegacyId(
                                        token,
                                        p.legacyId,
                                      );
                                      if (!ctx.mounted) return;
                                      scriptList
                                        ..clear()
                                        ..addAll(d.scripts);
                                      try {
                                        statsRef[0] =
                                            await fetchProjectStatsByLegacyId(
                                          token,
                                          p.legacyId,
                                        );
                                      } catch (_) {}
                                      setDialogState(() {});
                                    },
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('删除项目？'),
                                content: Text(
                                  '将删除 legacy #${p.legacyId} 及关联剧本/分镜（数据库级联），且清除该项目的 agent 记忆。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(c).pop(false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(c).pop(true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true || !ctx.mounted) return;
                            setDialogState(() => saving[0] = true);
                            try {
                              await deleteProjectByLegacyId(token, p.legacyId);
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              await _loadProjects();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('项目已删除'),
                                ),
                              );
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: const Text('DELETE'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            try {
                              await updateProjectByLegacyId(token, p.legacyId, {
                                'name': nameCtrl.text.isEmpty
                                    ? null
                                    : nameCtrl.text,
                                'intro': introCtrl.text.isEmpty
                                    ? null
                                    : introCtrl.text,
                              });
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              await _loadProjects();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving[0] ? '保存中…' : 'PATCH 保存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      nameCtrl.dispose();
      introCtrl.dispose();
    }
  }

  Future<void> _openScriptEditor(
    String token,
    int scriptLegacyId, {
    Future<void> Function()? onScriptTreeMutated,
  }) async {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    try {
      final script = await fetchScriptByLegacyId(token, scriptLegacyId);
      if (!mounted) return;
      nameCtrl.text = script.name ?? '';
      contentCtrl.text = script.content ?? '';
      stateCtrl.text = script.extractState?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text('Script #${script.legacyId}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentCtrl,
                        minLines: 4,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'Content (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'extract_state (empty = clear)',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: saving[0]
                              ? null
                              : () async {
                                  try {
                                    final boards =
                                        await fetchStoryboardsForScript(
                                      token,
                                      scriptLegacyId,
                                    );
                                    if (!mounted) return;
                                    final boardsList =
                                        List<StoryboardRow>.from(boards);
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx2) {
                                        final creatingSb = <bool>[false];
                                        return StatefulBuilder(
                                          builder: (ctx2, setBoardsState) {
                                            return AlertDialog(
                                              title: Text(
                                                '分镜 (${boardsList.length})',
                                              ),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                                  itemCount: boardsList.length,
                                            itemBuilder: (_, i) {
                                                    final b = boardsList[i];
                                              return ListTile(
                                                title: Text(
                                                  '#${b.legacyId} ${b.state ?? ""}',
                                                ),
                                                subtitle: Text(
                                                  b.prompt ?? '',
                                                  maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      onTap: creatingSb[0]
                                                          ? null
                                                          : () async {
                                                              await _openStoryboardEditor(
                                                    token,
                                                    b.legacyId,
                                                                onStoryboardTreeMutated:
                                                                    () async {
                                                                  final fresh =
                                                                      await fetchStoryboardsForScript(
                                                                    token,
                                                                    scriptLegacyId,
                                                                  );
                                                                  if (!ctx2
                                                                      .mounted) {
                                                                    return;
                                                                  }
                                                                  boardsList
                                                                    ..clear()
                                                                    ..addAll(
                                                                      fresh,
                                                                    );
                                                                  setBoardsState(
                                                                    () {},
                                                                  );
                                                                },
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                        actions: [
                                                TextButton(
                                                  onPressed: creatingSb[0]
                                                      ? null
                                                      : () async {
                                                          creatingSb[0] = true;
                                                          setBoardsState(() {});
                                                          try {
                                                            final row =
                                                                await createStoryboardUnderScriptLegacy(
                                                              token,
                                                              scriptLegacyId,
                                                            );
                                                            if (ctx2.mounted) {
                                                              boardsList
                                                                  .add(row);
                                                              ScaffoldMessenger
                                                                      .of(ctx2)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    '已创建分镜 legacy #${row.legacyId}',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          } on RustApiException catch (e) {
                                                            if (ctx2.mounted) {
                                                              ScaffoldMessenger
                                                                      .of(ctx2)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    e.toString(),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (ctx2.mounted) {
                                                              ScaffoldMessenger
                                                                      .of(ctx2)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    e.toString(),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          } finally {
                                                            creatingSb[0] =
                                                                false;
                                                            if (ctx2.mounted) {
                                                              setBoardsState(
                                                                () {},
                                                              );
                                                            }
                                                          }
                                                        },
                                                  child: Text(
                                                    creatingSb[0]
                                                        ? '创建中…'
                                                        : 'POST 空分镜',
                                                  ),
                                                ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx2).pop(),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } on RustApiException catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                          child: const Text('分镜列表…'),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('删除剧本？'),
                                content: Text(
                                  '将删除 script #${script.legacyId} 及其分镜（数据库级联）。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(c).pop(false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(c).pop(true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true || !ctx.mounted) return;
                            setDialogState(() => saving[0] = true);
                            try {
                              await deleteScriptByLegacyId(
                                token,
                                scriptLegacyId,
                              );
                              if (!ctx.mounted) return;
                              await onScriptTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('剧本已删除'),
                                ),
                              );
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: const Text('DELETE'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? extractParsed;
                            final st = stateCtrl.text.trim();
                            if (st.isNotEmpty) {
                              extractParsed = int.tryParse(st);
                              if (extractParsed == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('extract_state 须为整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateScriptByLegacyId(
                                token,
                                scriptLegacyId,
                                {
                                  'name': nameCtrl.text.isEmpty
                                      ? null
                                      : nameCtrl.text,
                                  'content': contentCtrl.text.isEmpty
                                      ? null
                                      : contentCtrl.text,
                                  'extract_state': st.isEmpty
                                      ? null
                                      : extractParsed,
                                },
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving[0] ? '保存中…' : 'PATCH 保存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      nameCtrl.dispose();
      contentCtrl.dispose();
      stateCtrl.dispose();
    }
  }

  Future<void> _openStoryboardEditor(
    String token,
    int storyLegacyId, {
    Future<void> Function()? onStoryboardTreeMutated,
  }) async {
    final promptCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final sbIdxCtrl = TextEditingController();
    final sgiCtrl = TextEditingController();
    try {
      final row = await fetchStoryboardByLegacyId(token, storyLegacyId);
      if (!mounted) return;
      promptCtrl.text = row.prompt ?? '';
      stateCtrl.text = row.state ?? '';
      videoCtrl.text = row.videoDesc ?? '';
      sbIdxCtrl.text = row.sbIndex?.toString() ?? '';
      sgiCtrl.text = row.shouldGenerateImage?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text('Storyboard #${row.legacyId}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: promptCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'prompt (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: stateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'state (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: videoCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'video_desc (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sbIdxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'sb_index (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sgiCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'should_generate_image (empty = clear)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('删除分镜？'),
                                content: Text(
                                  '将删除 storyboard #${row.legacyId}。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(c).pop(false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(c).pop(true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true || !ctx.mounted) return;
                            setDialogState(() => saving[0] = true);
                            try {
                              await deleteStoryboardByLegacyId(
                                token,
                                storyLegacyId,
                              );
                              if (!ctx.mounted) return;
                              await onStoryboardTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('分镜已删除'),
                                ),
                              );
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: const Text('DELETE'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? sbIdx;
                            final sbs = sbIdxCtrl.text.trim();
                            if (sbs.isNotEmpty) {
                              sbIdx = int.tryParse(sbs);
                              if (sbIdx == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('sb_index 须为整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            int? sgi;
                            final sgis = sgiCtrl.text.trim();
                            if (sgis.isNotEmpty) {
                              sgi = int.tryParse(sgis);
                              if (sgi == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'should_generate_image 须为整数',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateStoryboardByLegacyId(
                                token,
                                storyLegacyId,
                                {
                                  'prompt': promptCtrl.text.isEmpty
                                      ? null
                                      : promptCtrl.text,
                                  'state': stateCtrl.text.isEmpty
                                      ? null
                                      : stateCtrl.text,
                                  'video_desc': videoCtrl.text.isEmpty
                                      ? null
                                      : videoCtrl.text,
                                  'sb_index': sbs.isEmpty ? null : sbIdx,
                                  'should_generate_image':
                                      sgis.isEmpty ? null : sgi,
                                },
                              );
                              if (!ctx.mounted) return;
                              await onStoryboardTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving[0] ? '保存中…' : 'PATCH 保存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      promptCtrl.dispose();
      stateCtrl.dispose();
      videoCtrl.dispose();
      sbIdxCtrl.dispose();
      sgiCtrl.dispose();
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
          'payload': {
            'isolation_key': 'flutter-dev',
            'project_id': 1,
          },
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
      appBar: AppBar(
        title: const Text('Toonflow'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('API: $kApiBaseUrl', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
          FilledButton(
            onPressed: _loadingHealth ? null : _pingHealth,
            child: Text(_loadingHealth ? '请求中…' : 'GET /api/v1/health'),
              ),
              FilledButton.tonal(
                onPressed: _loadingHealthRoot ? null : _pingHealthRoot,
                child: Text(
                  _loadingHealthRoot ? '请求中…' : 'GET /health',
                ),
              ),
              FilledButton.tonal(
                onPressed: _loadingPing ? null : _pingPing,
                child: Text(
                  _loadingPing ? '请求中…' : 'GET /api/v1/ping',
                ),
              ),
            ],
          ),
          if (_healthBody != null) ...[
            const SizedBox(height: 8),
            Text('health (v1): $_healthBody'),
          ],
          if (_healthRootBody != null) ...[
            const SizedBox(height: 8),
            Text('health (root): $_healthRootBody'),
          ],
          if (_pingBody != null) ...[
            const SizedBox(height: 8),
            Text('ping: $_pingBody'),
          ],
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _loadingVersion ? null : _pingVersion,
            child: Text(_loadingVersion ? '请求中…' : 'GET /api/v1/version'),
          ),
          if (_versionBody != null) ...[
            const SizedBox(height: 8),
            Text('version: $_versionBody'),
          ],
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _loadingReady ? null : _pingReady,
            child: Text(_loadingReady ? '请求中…' : 'GET /api/v1/ready'),
          ),
          if (_readyBody != null) ...[
            const SizedBox(height: 8),
            Text('ready: $_readyBody'),
          ],
          const Divider(height: 32),
          Text(
            'Supabase Auth',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (!kSupabaseConfigured)
            Text(
              '未配置：运行示例\n'
              'flutter run --dart-define=SUPABASE_URL=... '
              '--dart-define=SUPABASE_ANON_KEY=...',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else ...[
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: _signIn, child: const Text('登录')),
                OutlinedButton(onPressed: _signUp, child: const Text('注册')),
                if (signedIn)
                  TextButton(onPressed: _signOut, child: const Text('退出')),
              ],
            ),
            if (signedIn) ...[
              const SizedBox(height: 12),
              Text('已登录 user: ${session.user.id}'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingMe ? null : _callMe,
                child: Text(_loadingMe ? '请求中…' : 'GET /api/v1/me (Bearer)'),
              ),
              if (_meBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('/me: $_meBody'),
              ],
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingUsageSummary ? null : _callUsageSummary,
                child: Text(
                  _loadingUsageSummary ? '请求中…' : 'GET /api/v1/usage/summary',
                ),
              ),
              if (_usageSummaryBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('usage: $_usageSummaryBody'),
              ],
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingPromptsProbe ? null : _callPromptsProbe,
                child: Text(
                  _loadingPromptsProbe ? '请求中…' : 'GET /api/v1/prompts',
                ),
              ),
              if (_promptsProbeBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('prompts: $_promptsProbeBody'),
              ],
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingVisualManualProbe
                    ? null
                    : _callVisualManualProbe,
                child: Text(
                  _loadingVisualManualProbe
                      ? '请求中…'
                      : 'GET /api/v1/visual-manual',
                ),
              ),
              if (_visualManualProbeBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('visual-manual: $_visualManualProbeBody'),
              ],
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingSkillsBinaryProbe ? null : _callSkillsBinaryProbe,
                child: Text(
                  _loadingSkillsBinaryProbe
                      ? '请求中…'
                      : 'GET /api/v1/skills/binary (_smoke PNG)',
                ),
              ),
              if (_skillsBinaryProbeBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('skills/binary: $_skillsBinaryProbeBody'),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _loadingModelsCatalog ? null : _callModelsCatalog,
                    child: Text(
                      _loadingModelsCatalog
                          ? '请求中…'
                          : 'GET /api/v1/models?type=all',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingTextModelDefault ? null : _callTextModelDefault,
                    child: Text(
                      _loadingTextModelDefault
                          ? '请求中…'
                          : 'GET /api/v1/models/text-default',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingModelDetail ? null : _callModelDetail,
                    child: Text(
                      _loadingModelDetail
                          ? '请求中…'
                          : 'GET /api/v1/models/detail (1:gpt-4o-mini)',
                    ),
                  ),
                ],
              ),
              if (_modelsCatalogBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('models: $_modelsCatalogBody'),
              ],
              if (_textModelDefaultBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('text-default: $_textModelDefaultBody'),
              ],
              if (_modelDetailBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('model detail: $_modelDetailBody'),
              ],
              const SizedBox(height: 16),
              Text(
                'Projects (RLS + Postgres)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
              FilledButton.tonal(
                    onPressed: (_loadingProjects || _creatingProject)
                        ? null
                        : _loadProjects,
                child: Text(
                  _loadingProjects ? '加载中…' : 'GET /api/v1/projects',
                ),
              ),
                  FilledButton.tonal(
                    onPressed: (_loadingProjectsSummary || _creatingProject)
                        ? null
                        : _loadProjectsSummary,
                    child: Text(
                      _loadingProjectsSummary
                          ? '加载中…'
                          : 'GET …/projects/summary',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: (_loadingArtStyles || _creatingProject)
                        ? null
                        : _loadArtStyles,
                    child: Text(
                      _loadingArtStyles ? '加载中…' : 'GET …/art-styles',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: (_loadingProjects || _creatingProject)
                        ? null
                        : _createEmptyProject,
                    child: Text(
                      _creatingProject ? '创建中…' : 'POST /api/v1/projects',
                    ),
                  ),
                ],
              ),
              if (_projectsSummaryLine != null) ...[
                const SizedBox(height: 8),
                SelectableText('summary: $_projectsSummaryLine'),
              ],
              if (_artStylesLine != null) ...[
                const SizedBox(height: 8),
                SelectableText('art-styles: $_artStylesLine'),
              ],
              if (_projects != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${_projects!.length} project(s)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ..._projects!.map(
                  (p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name ?? 'legacy #${p.legacyId}'),
                    subtitle: Text('legacy_id=${p.legacyId} · ${p.id}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openProjectDetail(p),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: _loadingAgentMemory ? null : _probeAgentMemory,
                  child: Text(
                    _loadingAgentMemory
                        ? '请求中…'
                        : 'POST /api/v1/agents/memory/query (first project)',
                  ),
                ),
                if (_agentMemoryBody != null) ...[
                  const SizedBox(height: 8),
                  SelectableText('agent memory: $_agentMemoryBody'),
                ],
              ],
              const SizedBox(height: 16),
              Text(
                'Generation jobs',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _loadingJobs ? null : _loadJobs,
                    child: Text(
                      _loadingJobs ? '…' : 'GET /api/v1/jobs',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingJobs ? null : _loadJobsKindFlutterProbe,
                    child: const Text('GET jobs?kind=flutter.probe'),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingJobs ? null : _loadJobsStatusFailed,
                    child: const Text('GET jobs?status=failed'),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        _loadingJobs ? null : _loadJobsKindProbeStatusQueued,
                    child: const Text(
                      'GET jobs?kind=flutter.probe&status=queued',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingJobKinds ? null : _loadJobKinds,
                    child: Text(
                      _loadingJobKinds ? '…' : 'GET /api/v1/jobs/kinds',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        _loadingJobKindSummary ? null : _loadJobKindSummary,
                    child: Text(
                      _loadingJobKindSummary
                          ? '…'
                          : 'GET …/jobs/kinds/summary',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingJobStatusSummary
                        ? null
                        : _loadJobStatusSummary,
                    child: Text(
                      _loadingJobStatusSummary
                          ? '…'
                          : 'GET …/jobs/status/summary',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _creatingJob ? null : _createProbeJob,
                    child: Text(
                      _creatingJob ? '…' : 'POST job (flutter.probe)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _jobIdCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Job id (tap a row below to paste)',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: (_loadingJobById ||
                        _jobIdCtrl.text.trim().isEmpty)
                    ? null
                    : _fetchJobById,
                child: Text(
                  _loadingJobById ? '…' : 'GET /api/v1/jobs/{id}',
                ),
              ),
              if (_jobByIdLine != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'job by id: $_jobByIdLine',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_jobKindsLine != null) ...[
                const SizedBox(height: 8),
                SelectableText('job kinds: $_jobKindsLine'),
              ],
              if (_jobKindSummaryLine != null) ...[
                const SizedBox(height: 8),
                SelectableText('job kinds/summary: $_jobKindSummaryLine'),
              ],
              if (_jobStatusSummaryLine != null) ...[
                const SizedBox(height: 8),
                SelectableText('job status/summary: $_jobStatusSummaryLine'),
              ],
              if (_jobs != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_jobs!.length} job(s)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ..._jobs!.take(8).map(
                      (j) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${j.kind} · ${j.status}'),
                        subtitle: Text(
                          [
                            j.id,
                            if (j.claimedBy != null &&
                                j.claimedBy!.isNotEmpty)
                              'claimed_by=${j.claimedBy}',
                          ].join(' · '),
                        ),
                        onTap: () =>
                            setState(() => _jobIdCtrl.text = j.id),
                        trailing: (j.status == 'failed' ||
                                j.status == 'queued' ||
                                j.status == 'running')
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  if (j.status == 'failed')
                                    TextButton(
                                      onPressed: _retryingJobId == j.id
                                          ? null
                                          : () => _retryFailedJob(j),
                                      child: Text(
                                        _retryingJobId == j.id ? '…' : '重试',
                                      ),
                                    ),
                                  if (j.status == 'queued' ||
                                      j.status == 'running')
                                    TextButton(
                                      onPressed: _cancellingJobId == j.id
                                          ? null
                                          : () => _cancelQueuedJob(j),
                                      child: Text(
                                        _cancellingJobId == j.id ? '…' : '取消',
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ),
              ],
              const SizedBox(height: 16),
              Text(
                'Harness / skills',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _loadingHarnessTools ? null : _loadHarnessTools,
                    child: Text(
                      _loadingHarnessTools ? '…' : 'GET /api/v1/harness/tools',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        _loadingSkillsSummary ? null : _loadSkillsAggregate,
                    child: Text(
                      _loadingSkillsSummary
                          ? '…'
                          : 'GET /api/v1/skills/summary',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingSkillList ? null : _loadSkillList,
                    child: Text(
                      _loadingSkillList ? '…' : 'GET /api/v1/skills',
                    ),
                  ),
                ],
              ),
              if (_harnessToolsLine != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'tools: $_harnessToolsLine',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_skillsAggregateLine != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'summary: $_skillsAggregateLine',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_skillsListSummary != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _skillsListSummary!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _skillPathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Skill relative path',
                  helperText:
                      'POST needs a path that does not exist yet under data/skills',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _skillContentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Body for PUT / POST',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed:
                        _loadingSkillPreview ? null : _previewSkillFile,
                    child: Text(
                      _loadingSkillPreview
                          ? '…'
                          : 'GET /api/v1/skills/content',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingSkillPut ? null : _putSkillProbe,
                    child: Text(
                      _loadingSkillPut ? '…' : 'PUT /api/v1/skills/content',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingSkillPost ? null : _postSkillProbe,
                    child: Text(
                      _loadingSkillPost ? '…' : 'POST /api/v1/skills/content',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingSkillDelete ? null : _deleteSkillProbe,
                    child: Text(
                      _loadingSkillDelete
                          ? '…'
                          : 'DELETE /api/v1/skills/content',
                    ),
                  ),
                ],
              ),
              if (_skillMutationLine != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _skillMutationLine!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _wsProbesBusy ? null : _testWebSocket,
                    child: Text(
                      _loadingWs ? '…' : 'WebSocket: attach + LLM stream',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _wsProbesBusy ? null : _testHarnessToolWebSocket,
                    child: Text(
                      _loadingWsHarness ? '…' : 'WS: harness.tool.invoke (echo)',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        _wsProbesBusy ? null : _testHarnessIsolatedEchoWebSocket,
                    child: Text(
                      _loadingWsIsolatedEcho
                          ? '…'
                          : 'WS: isolated.echo (subprocess)',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _wsProbesBusy ? null : _testHarnessSkillsReadWebSocket,
                    child: Text(
                      _loadingWsSkillsRead
                          ? '…'
                          : 'WS: skills.read (path field)',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed:
                        _wsProbesBusy ? null : _testHarnessAgentRunWebSocket,
                    child: Text(
                      _loadingWsHarnessAgent
                          ? '…'
                          : 'WS: harness.agent.run (needs LLM key)',
                    ),
                  ),
                ],
              ),
              if (_wsLog.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('WS 最近消息:', style: Theme.of(context).textTheme.labelLarge),
                ..._wsLog.map((l) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SelectableText(l, style: Theme.of(context).textTheme.bodySmall),
                    )),
              ],
            ],
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
