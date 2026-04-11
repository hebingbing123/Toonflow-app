import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'home_page/novel_workbench_support.dart';
import 'home_page/project_assets_generation_workbench_support.dart';
import 'home_page/project_editor_assets_workbench_support.dart';
import 'home_page/script_workbench_support.dart';
import 'home_page/storyboard_workbench_support.dart';
import 'home_page/sections.dart';
import 'home_page/workspace_ws_event_resolution.dart';
import 'rust_api.dart';

part 'home_page/project_editor.dart';
part 'home_page/project_editor_legacy_probes.dart';
part 'home_page/project_editor_legacy_general_probe.dart';
part 'home_page/project_editor_legacy_project_probe.dart';
part 'home_page/project_editor_legacy_tasks_probe.dart';
part 'home_page/project_editor_assets_images_probe.dart';
part 'home_page/project_editor_assets_crud_probe.dart';
part 'home_page/project_editor_assets_links_probe.dart';
part 'home_page/project_editor_assets_corner_scape_workbench.dart';
part 'home_page/project_editor_assets_clip_upload_workbench.dart';
part 'home_page/project_editor_assets_generation_workbench.dart';
part 'home_page/project_editor_assets_generation_workbench_dialog.dart';
part 'home_page/project_editor_assets_images_workbench.dart';
part 'home_page/project_editor_assets_workbench.dart';
part 'home_page/project_editor_novels_legacy_actions.dart';
part 'home_page/project_editor_novels_legacy_probe.dart';
part 'home_page/project_editor_novel_events_actions.dart';
part 'home_page/project_editor_novel_events_probe.dart';
part 'home_page/project_editor_novel_events_workbench.dart';
part 'home_page/project_editor_novels_workbench.dart';
part 'home_page/project_editor_novels.dart';
part 'home_page/project_editor_assets.dart';
part 'home_page/project_editor_assets_dialogs.dart';
part 'home_page/project_editor_dialog_basics.dart';
part 'home_page/project_editor_dialog_state.dart';
part 'home_page/project_editor_dialog_actions.dart';
part 'home_page/project_editor_dialog_content.dart';
part 'home_page/project_editor_scripts_probe.dart';
part 'home_page/project_editor_scripts_workbench.dart';
part 'home_page/project_editor_scripts.dart';
part 'home_page/projects_controller.dart';
part 'home_page/jobs_controller_list.dart';
part 'home_page/jobs_controller_summary.dart';
part 'home_page/jobs_controller_actions.dart';
part 'home_page/jobs_controller.dart';
part 'home_page/task_center_controller.dart';
part 'home_page/agent_workspaces_controller.dart';
part 'home_page/skills_harness_controller.dart';
part 'home_page/script_editor_storyboards.dart';
part 'home_page/quality_reviews_controller_summary.dart';
part 'home_page/quality_reviews_controller.dart';
part 'home_page/system_probes_controller.dart';
part 'home_page/system_probes_models_catalog.dart';
part 'home_page/system_probes_models_catalog_settings_probe.dart';
part 'home_page/system_probes_models_catalog_production_probe.dart';
part 'home_page/system_probes_account_settings.dart';
part 'home_page/system_probes_account.dart';
part 'home_page/system_probes_content.dart';
part 'home_page/skills_harness_websocket.dart';
part 'home_page/skills_harness_files.dart';
part 'home_page/auth_session_controller.dart';
part 'home_page/overview_controller.dart';
part 'home_page/build_sections.dart';
part 'home_page/runtime_helpers.dart';
part 'home_page/script_editor.dart';
part 'home_page/script_editor_edit_image_workbench.dart';
part 'home_page/script_editor_workbench.dart';
part 'home_page/storyboard_editor.dart';
part 'home_page/script_editor_storyboards_workbench.dart';
part 'home_page/storyboard_editor_workbench.dart';
part 'home_page/storyboard_editor_workbench_video.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _HomeSectionMode { product, debug }

enum _ProductWorkspacePane {
  projects,
  scriptWorkspace,
  productionWorkspace,
  workspaceActivity,
  tasks,
  jobs,
  quality,
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
  bool _loadingScriptWorkspaceRun = false;
  bool _loadingProductionWorkspaceRun = false;
  bool _loadingProductionFlowProbe = false;
  bool _loadingScriptDomainProbe = false;
  bool _loadingScriptSubAgentRun = false;
  bool _loadingProductionSubAgentRun = false;
  bool _loadingScriptResultWriteback = false;
  bool _loadingScriptPlanResultWriteback = false;
  bool _loadingProductionResultWriteback = false;
  final List<String> _wsLog = [];
  String _workspaceAssistantText = '';
  String? _workspaceLastToolResultLine;
  String? _workspaceLastToolName;
  Object? _workspaceLastToolResultData;
  String? _workspaceSuggestedFlowKey;
  String? _workspaceScriptWritebackCandidate;
  Map<String, dynamic>? _workspaceScriptPlanWritebackCandidate;
  int? _workspaceScriptPlanRowId;
  String? _workspaceScriptWritebackSource;
  String? _workspaceWritebackLine;
  final _agentWorkspaceProjectIdCtrl = TextEditingController(text: '1');
  final _agentWorkspaceScriptIdCtrl = TextEditingController(text: '1');
  final _scriptWorkspacePromptCtrl = TextEditingController(
    text: '先读取 get_planData 与 get_novel_events，总结当前剧情骨架缺口，再给出下一轮 script 生成建议。',
  );
  final _scriptDomainArgsCtrl = TextEditingController(text: '{}');
  final _productionWorkspacePromptCtrl = TextEditingController(
    text: '先调用 get_flowData key=assets，然后总结当前资产与可执行的下一步 production 操作。',
  );
  final _productionFlowKeyCtrl = TextEditingController(text: 'assets');
  final _productionDomainToolCtrl = TextEditingController(text: 'get_flowData');
  final _productionDomainArgsCtrl = TextEditingController(text: '{}');
  final _scriptSubAgentToolCtrl = TextEditingController(
    text: 'run_sub_agent_storySkeleton',
  );
  final _productionSubAgentToolCtrl = TextEditingController(
    text: 'run_sub_agent_director_plan',
  );

  bool _loadingProjects = false;
  bool _loadingProjectsSummary = false;
  bool _loadingArtStyles = false;
  bool _creatingProject = false;
  List<ProjectRow>? _projects;
  List<ArtStyleRow>? _artStyles;
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

  bool _loadingTaskProjects = false;
  bool _loadingTaskCategories = false;
  bool _loadingTaskApi = false;
  bool _loadingTaskDetailsLegacy = false;
  bool _loadingTaskDetailsUuid = false;
  List<LegacyTasksProjectItem>? _taskProjects;
  List<JobRow>? _taskApiJobs;
  String? _taskCategoriesLine;
  String? _taskApiSummaryLine;
  String? _taskDetailLegacyLine;
  String? _taskDetailUuidLine;
  final _taskDetailJobIdCtrl = TextEditingController();

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
  _HomeSectionMode _homeSectionMode = _HomeSectionMode.product;
  _ProductWorkspacePane _productWorkspacePane = _ProductWorkspacePane.projects;

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
    _taskDetailJobIdCtrl.dispose();
    _qualityReviewIdCtrl.dispose();
    _skillPathCtrl.dispose();
    _skillContentCtrl.dispose();
    _agentWorkspaceProjectIdCtrl.dispose();
    _agentWorkspaceScriptIdCtrl.dispose();
    _scriptWorkspacePromptCtrl.dispose();
    _scriptDomainArgsCtrl.dispose();
    _productionWorkspacePromptCtrl.dispose();
    _productionFlowKeyCtrl.dispose();
    _productionDomainToolCtrl.dispose();
    _productionDomainArgsCtrl.dispose();
    _scriptSubAgentToolCtrl.dispose();
    _productionSubAgentToolCtrl.dispose();
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
