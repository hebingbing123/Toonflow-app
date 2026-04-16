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
import 'auth/controller.dart';
import 'jobs/controller.dart';
import 'projects/controller.dart';
import 'quality_reviews/controller.dart';
import 'shell/sections.dart';
import 'shell/workspace_ws_event_resolution.dart';
import 'skills_harness/controller.dart';
import 'overview/controller.dart';
import 'system_probes/account/controller.dart';
import 'system_probes/content/controller.dart';
import 'system_probes/models_catalog/controller.dart';
import 'task_center/controller.dart';
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
part 'agent_workspaces/controller/constants.dart';
part 'agent_workspaces/controller/utils.dart';
part 'agent_workspaces/controller/script.dart';
part 'agent_workspaces/controller/production.dart';
part 'agent_workspaces/controller/writeback.dart';
part 'script_editor/storyboards/dialogs/add.dart';
part 'script_editor/storyboards/dialogs/batch_add.dart';
part 'script_editor/storyboards/workbench.dart';
part 'system_probes/controller.dart';
part 'system_probes/models_catalog/settings_probe.dart';
part 'system_probes/models_catalog/production_probe.dart';
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
  String? _error;
  bool _loadingScriptWorkspaceRun = false;
  bool _loadingProductionWorkspaceRun = false;
  bool _loadingProductionFlowProbe = false;
  bool _loadingScriptDomainProbe = false;
  bool _loadingScriptSubAgentRun = false;
  bool _loadingProductionSubAgentRun = false;
  bool _loadingScriptResultWriteback = false;
  bool _loadingScriptPlanResultWriteback = false;
  bool _loadingProductionResultWriteback = false;
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

  late final TaskCenterController _taskCenterController = TaskCenterController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
  );

  late final QualityReviewsController _qualityReviewsController =
      QualityReviewsController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
      );

  late final OverviewController _overviewController = OverviewController(
    onErrorChanged: _setSharedError,
  );

  late final AccountProbesController _accountProbesController =
      AccountProbesController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
      );

  late final ContentProbesController _contentProbesController =
      ContentProbesController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
      );

  late final ModelsCatalogController _modelsCatalogController =
      ModelsCatalogController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        runSettingsAndAssetsProbes: _runModelsCatalogSettingsAndAssetsProbes,
        runProductionProbes: _runModelsCatalogProductionProbes,
        formatProbeStatusMap: _formatProbeStatusMap,
      );

  late final AuthController _authController = AuthController(
    onErrorChanged: _setSharedError,
    onSignedOut: _handleSignedOut,
  );

  _HomeSectionMode _homeSectionMode = _HomeSectionMode.product;
  _ProductWorkspacePane _productWorkspacePane = _ProductWorkspacePane.projects;

  late final SkillsHarnessController _skillsHarnessController =
      SkillsHarnessController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        onWsMessage: _handleHarnessWsMessage,
        onWsLifecycleSettled: _resetWorkspaceWsOperationFlags,
      );

  bool get _loadingWs => _skillsHarnessController.loadingWs;
  bool get _loadingWsHarness => _skillsHarnessController.loadingWsHarness;
  bool get _loadingWsIsolatedEcho =>
      _skillsHarnessController.loadingWsIsolatedEcho;
  bool get _loadingWsWasmProbe => _skillsHarnessController.loadingWsWasmProbe;
  bool get _loadingWsHarnessAgent =>
      _skillsHarnessController.loadingWsHarnessAgent;
  bool get _loadingWsSkillsRead => _skillsHarnessController.loadingWsSkillsRead;
  List<String> get _wsLog => _skillsHarnessController.wsLog;
  bool get _loadingHealth => _overviewController.loadingHealth;
  bool get _loadingHealthRoot => _overviewController.loadingHealthRoot;
  bool get _loadingPing => _overviewController.loadingPing;
  bool get _loadingVersion => _overviewController.loadingVersion;
  bool get _loadingReady => _overviewController.loadingReady;
  String? get _healthBody => _overviewController.healthBody;
  String? get _healthRootBody => _overviewController.healthRootBody;
  String? get _pingBody => _overviewController.pingBody;
  String? get _versionBody => _overviewController.versionBody;
  String? get _readyBody => _overviewController.readyBody;

  Future<WebSocketChannel?> _openHarnessChannel(String token) =>
      _skillsHarnessController.openHarnessChannel(token);

  void _setSharedError(String? error) {
    if (!mounted) return;
    setState(() {
      _error = error;
    });
  }

  @override
  void initState() {
    super.initState();
    _authController.addListener(_handleAuthChanged);
    _accountProbesController.addListener(_handleAccountProbesChanged);
    _contentProbesController.addListener(_handleContentProbesChanged);
    _modelsCatalogController.addListener(_handleModelsCatalogChanged);
    _overviewController.addListener(_handleOverviewChanged);
    _taskCenterController.addListener(_handleTaskCenterChanged);
    _skillsHarnessController.addListener(_handleSkillsHarnessChanged);
    if (kSupabaseConfigured) {
      _authController.attachAuthListener();
    }
  }

  void _handleAuthChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleAccountProbesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleContentProbesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleModelsCatalogChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleSkillsHarnessChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleOverviewChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleTaskCenterChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleSignedOut() async {
    await _skillsHarnessController.closeChannel();
    _accountProbesController.reset();
    _contentProbesController.reset();
    _modelsCatalogController.reset();
    _overviewController.reset();
    _skillsHarnessController.reset();
    _projectsController.reset();
    _jobsController.reset();
    _taskCenterController.reset();
    _qualityReviewsController.reset();
  }

  @override
  void dispose() {
    _authController.removeListener(_handleAuthChanged);
    _accountProbesController.removeListener(_handleAccountProbesChanged);
    _contentProbesController.removeListener(_handleContentProbesChanged);
    _modelsCatalogController.removeListener(_handleModelsCatalogChanged);
    _overviewController.removeListener(_handleOverviewChanged);
    _taskCenterController.removeListener(_handleTaskCenterChanged);
    _skillsHarnessController.removeListener(_handleSkillsHarnessChanged);
    _authController.dispose();
    _accountProbesController.dispose();
    _contentProbesController.dispose();
    _modelsCatalogController.dispose();
    _overviewController.dispose();
    _projectsController.dispose();
    _jobsController.dispose();
    _taskCenterController.dispose();
    _qualityReviewsController.dispose();
    _skillsHarnessController.dispose();
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
    final session = _authController.session;

    return Scaffold(
      appBar: AppBar(title: const Text('OpenFlow')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: _buildHomePageSections(context, session),
      ),
    );
  }
}
