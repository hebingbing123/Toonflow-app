import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'project_editor/assets/clip_upload_launcher.dart';
import 'project_editor/assets/upload_edit_image_launcher.dart';
import 'project_editor/assets/link_dialog_launcher.dart';
import 'project_editor/assets/section_builder.dart';
import 'project_editor/novels/events/section_builder.dart';
import 'project_editor/novels/workbench_section_builder.dart';
import 'project_editor/assets/generation/section_launcher.dart';
import 'project_editor/assets/images/workbench_launcher.dart';
import 'project_editor/assets/corner_scape_launcher.dart';
import 'project_editor/assets/workbench/dialog_launcher.dart';
import 'project_editor/novels/support.dart';
import 'project_editor/novels/workbench_launcher.dart';
import 'project_editor/novels/events/workbench_launcher.dart';
import 'project_editor/scripts/section_builder.dart';
import 'project_editor/scripts/workbench/dialog_launcher.dart';
import 'script_editor/edit_image/workbench_view.dart';
import 'script_editor/workbench_view.dart';
import 'script_editor/storyboards/workbench_view.dart';
import 'script_editor/support.dart';
import 'storyboard_editor/support.dart';
import 'agent_workspaces/controls.dart';
import 'jobs/controller.dart';
import 'projects/controller.dart';
import 'quality_reviews/controller.dart';
import 'shell/sections.dart';
import 'shell/workspace_ws_event_resolution.dart';
import 'rust_api.dart';

part 'project_editor/editor.dart';
part 'project_editor/http_probes/general_probe.dart';
part 'project_editor/http_probes/project_probe.dart';
part 'project_editor/http_probes/tasks_probe.dart';
part 'project_editor/assets/compatibility/images.dart';
part 'project_editor/assets/compatibility/images_actions.dart';
part 'project_editor/assets/compatibility/images_crud_actions.dart';
part 'project_editor/assets/compatibility/images_workbench_actions.dart';
part 'project_editor/assets/compatibility/crud_primary.dart';
part 'project_editor/assets/compatibility/crud_query.dart';
part 'project_editor/assets/compatibility/relations.dart';
part 'project_editor/novels/compatibility/actions.dart';
part 'project_editor/novels/compatibility/section.dart';
part 'project_editor/novels/events/actions.dart';
part 'project_editor/novels/events/compatibility.dart';
part 'project_editor/novels/actions.dart';
part 'project_editor/novels/sections/search.dart';
part 'project_editor/novels/sections/create.dart';
part 'project_editor/novels/sections/edit.dart';
part 'project_editor/novels/sections/delete_snapshot.dart';
part 'project_editor/assets/dialogs/create_edit.dart';
part 'project_editor/assets/dialogs/delete.dart';
part 'project_editor/assets/dialogs/filter.dart';
part 'project_editor/scripts/probe/actions.dart';
part 'project_editor/scripts/dialogs/batch_add.dart';
part 'task_center/controller.dart';
part 'agent_workspaces/controller/constants.dart';
part 'agent_workspaces/controller/utils.dart';
part 'agent_workspaces/controller/script.dart';
part 'agent_workspaces/controller/production.dart';
part 'agent_workspaces/controller/writeback.dart';
part 'skills_harness/controller.dart';
part 'script_editor/storyboards/dialogs/add.dart';
part 'script_editor/storyboards/dialogs/batch_add.dart';
part 'script_editor/storyboards/workbench.dart';
part 'system_probes/controller.dart';
part 'system_probes/models_catalog/catalog.dart';
part 'system_probes/models_catalog/settings_probe.dart';
part 'system_probes/models_catalog/production_probe.dart';
part 'system_probes/account/settings.dart';
part 'system_probes/account/profile.dart';
part 'system_probes/content.dart';
part 'skills_harness/websocket.dart';
part 'skills_harness/files.dart';
part 'auth/controller.dart';
part 'overview/controller.dart';
part 'shell/build_sections.dart';
part 'shell/runtime_helpers.dart';
part 'script_editor/editor.dart';
part 'script_editor/edit_image/workbench.dart';
part 'script_editor/workbench.dart';
part 'storyboard_editor/editor.dart';
part 'script_editor/batch/workbench.dart';
part 'script_editor/batch/dialog.dart';
part 'script_editor/batch/actions.dart';
part 'script_editor/batch/sections.dart';
part 'storyboard_editor/workbench.dart';
part 'storyboard_editor/actions.dart';
part 'storyboard_editor/data.dart';
part 'storyboard_editor/state.dart';
part 'storyboard_editor/status_panels.dart';
part 'storyboard_editor/image_section.dart';
part 'storyboard_editor/video_section.dart';

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

  late final ProjectsController _projectsController = ProjectsController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
  );

  late final JobsController _jobsController = JobsController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
  );

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

  late final QualityReviewsController _qualityReviewsController =
      QualityReviewsController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
      );

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

  void _setSharedError(String? error) {
    if (!mounted) return;
    setState(() {
      _error = error;
    });
  }

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
    _projectsController.dispose();
    _jobsController.dispose();
    _taskDetailJobIdCtrl.dispose();
    _qualityReviewsController.dispose();
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
      appBar: AppBar(title: const Text('OpenFlow')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: _buildHomePageSections(context, session),
      ),
    );
  }
}
