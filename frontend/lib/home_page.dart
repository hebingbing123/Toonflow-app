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
part 'home_page/project_editor_legacy_probes.dart';
part 'home_page/project_editor_novels.dart';
part 'home_page/project_editor_assets.dart';
part 'home_page/project_editor_scripts.dart';
part 'home_page/projects_controller.dart';
part 'home_page/jobs_controller.dart';
part 'home_page/skills_harness_controller.dart';
part 'home_page/quality_reviews_controller.dart';
part 'home_page/system_probes_controller.dart';
part 'home_page/system_probes_models_catalog.dart';
part 'home_page/system_probes_account.dart';
part 'home_page/auth_session_controller.dart';
part 'home_page/overview_controller.dart';
part 'home_page/build_sections.dart';
part 'home_page/runtime_helpers.dart';
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

/// Production probes: allow implemented **200**, missing owned data **404**, or **503** when DB-gated routes run without pool.
bool _productionProbeOk(int status) =>
    status == 200 || status == 404 || status == 503;

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

  bool _loadingQualityReviews = false;
  bool _loadingQualityBadCases = false;
  bool _loadingQualityStats = false;
  bool _loadingQualityStagePassRate = false;
  bool _creatingQualityReview = false;
  bool _loadingQualityReviewById = false;
  String? _qualityStatsLine;
  String? _qualityStagePassRateLine;
  String? _qualityReviewByIdLine;
  List<QualityReview>? _qualityReviews;
  final _qualityReviewIdCtrl = TextEditingController();

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
    _qualityReviewIdCtrl.dispose();
    _skillPathCtrl.dispose();
    _skillContentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Toonflow')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: _buildHomePageSections(context, session),
      ),
    );
  }
}
