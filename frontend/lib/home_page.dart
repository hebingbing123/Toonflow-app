import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'home_page/project_editor/novels/support.dart';
import 'home_page/project_editor/assets/generation/support.dart';
import 'home_page/project_editor/assets/support.dart';
import 'home_page/script_editor/support.dart';
import 'home_page/storyboard_editor/support.dart';
import 'home_page/shell/sections.dart';
import 'home_page/shell/workspace_ws_event_resolution.dart';
import 'rust_api.dart';

part 'home_page/project_editor/editor.dart';
part 'home_page/project_editor/http_probes/probes.dart';
part 'home_page/project_editor/http_probes/general_probe.dart';
part 'home_page/project_editor/http_probes/project_probe.dart';
part 'home_page/project_editor/http_probes/tasks_probe.dart';
part 'home_page/project_editor/assets/compatibility/images.dart';
part 'home_page/project_editor/assets/compatibility/crud.dart';
part 'home_page/project_editor/assets/compatibility/relations.dart';
part 'home_page/project_editor/assets/corner_scape.dart';
part 'home_page/project_editor/assets/clip_upload.dart';
part 'home_page/project_editor/assets/section.dart';
part 'home_page/project_editor/assets/generation/section.dart';
part 'home_page/project_editor/assets/generation/dialog.dart';
part 'home_page/project_editor/assets/generation/actions.dart';
part 'home_page/project_editor/assets/generation/controls.dart';
part 'home_page/project_editor/assets/generation/selection.dart';
part 'home_page/project_editor/assets/generation/status.dart';
part 'home_page/project_editor/assets/images.dart';
part 'home_page/project_editor/assets/workbench.dart';
part 'home_page/project_editor/novels/compatibility/actions.dart';
part 'home_page/project_editor/novels/compatibility/section.dart';
part 'home_page/project_editor/novels/events/actions.dart';
part 'home_page/project_editor/novels/events/compatibility.dart';
part 'home_page/project_editor/novels/events/section.dart';
part 'home_page/project_editor/novels/workbench.dart';
part 'home_page/project_editor/novels/novels.dart';
part 'home_page/project_editor/assets/assets.dart';
part 'home_page/project_editor/assets/dialogs.dart';
part 'home_page/project_editor/dialog/basics.dart';
part 'home_page/project_editor/dialog/state.dart';
part 'home_page/project_editor/dialog/actions.dart';
part 'home_page/project_editor/dialog/content.dart';
part 'home_page/project_editor/scripts/probe.dart';
part 'home_page/project_editor/scripts/workbench.dart';
part 'home_page/project_editor/scripts/scripts.dart';
part 'home_page/projects/controller.dart';
part 'home_page/jobs/list.dart';
part 'home_page/jobs/summary.dart';
part 'home_page/jobs/actions.dart';
part 'home_page/jobs/controller.dart';
part 'home_page/task_center/controller.dart';
part 'home_page/agent_workspaces/controller.dart';
part 'home_page/skills_harness/controller.dart';
part 'home_page/script_editor/storyboards.dart';
part 'home_page/quality_reviews/summary.dart';
part 'home_page/quality_reviews/controller.dart';
part 'home_page/system_probes/controller.dart';
part 'home_page/system_probes/models_catalog/catalog.dart';
part 'home_page/system_probes/models_catalog/settings_probe.dart';
part 'home_page/system_probes/models_catalog/production_probe.dart';
part 'home_page/system_probes/account/settings.dart';
part 'home_page/system_probes/account/profile.dart';
part 'home_page/system_probes/content.dart';
part 'home_page/skills_harness/websocket.dart';
part 'home_page/skills_harness/files.dart';
part 'home_page/auth/controller.dart';
part 'home_page/overview/controller.dart';
part 'home_page/shell/build_sections.dart';
part 'home_page/shell/runtime_helpers.dart';
part 'home_page/script_editor/editor.dart';
part 'home_page/script_editor/edit_image.dart';
part 'home_page/script_editor/workbench.dart';
part 'home_page/storyboard_editor/editor.dart';
part 'home_page/script_editor/batch_workbench.dart';
part 'home_page/script_editor/batch_dialog.dart';
part 'home_page/storyboard_editor/workbench.dart';
part 'home_page/storyboard_editor/status_panels.dart';
part 'home_page/storyboard_editor/image_section.dart';
part 'home_page/storyboard_editor/video_section.dart';

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
  bool _loadingTaskDetailsByNumericId = false;
  bool _loadingTaskDetailsUuid = false;
  List<TaskCenterProjectItem>? _taskProjects;
  List<JobRow>? _taskApiJobs;
  String? _taskCategoriesLine;
  String? _taskApiSummaryLine;
  String? _taskDetailNumericIdLine;
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
