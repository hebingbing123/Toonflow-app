import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'home_page/sections.dart';
import 'rust_api.dart';

part 'home_page/project_editor.dart';
part 'home_page/projects_controller.dart';
part 'home_page/jobs_controller.dart';
part 'home_page/skills_harness_controller.dart';
part 'home_page/system_probes_controller.dart';
part 'home_page/auth_session_controller.dart';
part 'home_page/script_editor.dart';
part 'home_page/storyboard_editor.dart';

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
  bool _loadingWsWasmProbe = false;
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
      _loadingWsWasmProbe ||
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
              loadingWsWasmProbe: _loadingWsWasmProbe,
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
              onTestHarnessWasmProbeWebSocket: _testHarnessWasmProbeWebSocket,
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
