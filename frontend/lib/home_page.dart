import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'project_editor/assets/clip_upload_launcher.dart';
import 'project_editor/assets/upload_edit_image_launcher.dart';
import 'project_editor/assets/link_dialog_launcher.dart';
import 'project_editor/assets/section_builder.dart';
import 'project_editor/novels/events/section_builder.dart';
import 'project_editor/novels/import_parser.dart';
import 'project_editor/novels/workbench_section_builder.dart';
import 'project_editor/assets/generation/section_launcher.dart';
import 'project_editor/assets/images/workbench_launcher.dart';
import 'project_editor/assets/corner_scape_launcher.dart';
import 'project_editor/assets/workbench/dialog_launcher.dart';
import 'project_editor/novels/support.dart';
import 'project_editor/novels/workbench_launcher.dart';
import 'project_editor/novels/events/workbench_launcher.dart';
import 'project_editor/scripts/section_builder.dart';
import 'project_editor/scripts/plan_workbench_view.dart';
import 'project_editor/scripts/plan_workbench_support.dart';
import 'project_editor/scripts/workbench/dialog_launcher.dart';
import 'script_editor/edit_image/workbench_view.dart';
import 'script_editor/workbench_view.dart';
import 'script_editor/storyboards/workbench_view.dart';
import 'script_editor/support.dart';
import 'storyboard_editor/support.dart';
import 'agent_workspaces/controls.dart';
import 'agent_workspaces/input_controller.dart';
import 'agent_workspaces/operation_controller.dart';
import 'agent_workspaces/run_controller.dart';
import 'agent_workspaces/runtime_output_controller.dart';
import 'agent_workspaces/ws_event_controller.dart';
import 'agent_workspaces/writeback_controller.dart';
import 'auth/controller.dart';
import 'jobs/controller.dart';
import 'projects/controller.dart';
import 'quality_reviews/controller.dart';
import 'shell/navigation_controller.dart';
import 'shell/sections.dart';
import 'shell/workspace_context_view.dart';
import 'skills_harness/controller.dart';
import 'overview/controller.dart';
import 'system_probes/account/controller.dart';
import 'system_probes/content/controller.dart';
import 'system_probes/models_catalog/controller.dart';
import 'task_center/controller.dart';
import 'task_center/support.dart';
import 'rust_api.dart';

part 'project_editor/editor.dart';
part 'project_editor/editor_dialog_basics.dart';
part 'project_editor/editor_dialog_content.dart';
part 'project_editor/editor_dialog_content_novels.dart';
part 'project_editor/editor_dialog_content_assets.dart';
part 'project_editor/editor_dialog_content_scripts.dart';
part 'project_editor/editor_dialog_actions.dart';
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
part 'project_editor/novels/compatibility/actions_probe_reads.dart';
part 'project_editor/novels/compatibility/actions_probe_mutations.dart';
part 'project_editor/novels/compatibility/section.dart';
part 'project_editor/novels/events/actions.dart';
part 'project_editor/novels/events/compatibility.dart';
part 'project_editor/novels/actions.dart';
part 'project_editor/novels/sections/search.dart';
part 'project_editor/novels/sections/import_book.dart';
part 'project_editor/novels/sections/create.dart';
part 'project_editor/novels/sections/edit.dart';
part 'project_editor/novels/sections/delete_snapshot.dart';
part 'project_editor/assets/dialogs/create_edit.dart';
part 'project_editor/assets/dialogs/delete.dart';
part 'project_editor/assets/dialogs/filter.dart';
part 'project_editor/scripts/probe/actions.dart';
part 'project_editor/scripts/plan_workbench.dart';
part 'project_editor/scripts/dialogs/batch_add.dart';
part 'script_editor/storyboards/dialogs/add.dart';
part 'script_editor/storyboards/dialogs/batch_add.dart';
part 'script_editor/storyboards/workbench.dart';
part 'system_probes/controller.dart';
part 'system_probes/models_catalog/settings_probe.dart';
part 'system_probes/models_catalog/settings_probe_core.dart';
part 'system_probes/models_catalog/settings_probe_vendor_assets.dart';
part 'system_probes/models_catalog/production_probe.dart';
part 'system_probes/models_catalog/production_probe_typed.dart';
part 'shell/build_sections.dart';
part 'shell/build_sections_product.dart';
part 'shell/build_sections_debug.dart';
part 'shell/runtime_helpers.dart';
part 'script_editor/editor.dart';
part 'script_editor/edit_image/workbench.dart';
part 'script_editor/workbench.dart';
part 'storyboard_editor/editor.dart';
part 'script_editor/batch/workbench.dart';
part 'script_editor/batch/dialog.dart';
part 'script_editor/batch/dialog_controllers.dart';
part 'script_editor/batch/actions.dart';
part 'script_editor/batch/sections.dart';
part 'storyboard_editor/workbench.dart';
part 'storyboard_editor/actions.dart';
part 'storyboard_editor/actions/patch_helpers.dart';
part 'storyboard_editor/actions/video_helpers.dart';
part 'storyboard_editor/actions/quality_helpers.dart';
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

class _HomePageState extends State<HomePage> {
  String? _error;
  int? _productScopedProjectNumericId;
  MeResponse? _sessionMe;
  String? _lastSessionAccessToken;
  bool _loadingSessionMe = false;
  final _workspaceInputController = WorkspaceInputController();
  final _workspaceOperationController = WorkspaceOperationController();
  late final WorkspaceRunController _workspaceRunController =
      WorkspaceRunController(
        inputController: _workspaceInputController,
        operationController: _workspaceOperationController,
        outputController: _workspaceOutputController,
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        clearWsLog: _skillsHarnessController.wsLog.clear,
        resetWorkspaceOutputs: () {
          _workspaceOutputController.reset();
        },
        requestSender: _sendWorkspaceHarnessMessages,
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

  late final ShellNavigationController _shellNavigationController =
      ShellNavigationController();
  late final WorkspaceOutputController _workspaceOutputController =
      WorkspaceOutputController();
  late final WorkspaceWsEventController _workspaceWsEventController =
      WorkspaceWsEventController(
        skillsHarnessBusyProvider: () => _skillsHarnessController.wsProbesBusy,
        resetSkillsHarnessBusyFlags: () {
          _skillsHarnessController.resetWsBusyFlags();
        },
        clearSkillsHarnessToolProbeFlags: () {
          _skillsHarnessController.clearToolProbeFlags();
        },
        clearSkillsHarnessAgentProbeFlags: () {
          _skillsHarnessController.clearAgentProbeFlags();
        },
        operationController: _workspaceOperationController,
        outputController: _workspaceOutputController,
        inputController: _workspaceInputController,
      );
  late final WorkspaceWritebackController _workspaceWritebackController =
      WorkspaceWritebackController(
        inputController: _workspaceInputController,
        outputController: _workspaceOutputController,
        operationController: _workspaceOperationController,
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
      );

  late final SkillsHarnessController _skillsHarnessController =
      SkillsHarnessController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        onWsMessage: (raw) {
          _workspaceWsEventController.handleRawMessage(raw);
        },
        onWsLifecycleSettled: () {
          _workspaceWsEventController.resetWsOperationFlags();
        },
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

  Future<bool> _sendWorkspaceHarnessMessages(
    String token,
    List<Map<String, dynamic>> messages,
  ) async {
    final channel = await _openHarnessChannel(token);
    if (channel == null) {
      return false;
    }
    for (final message in messages) {
      channel.sink.add(jsonEncode(message));
    }
    return true;
  }

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
    _shellNavigationController.addListener(_handleShellNavigationChanged);
    _workspaceOperationController.addListener(_handleWorkspaceOperationChanged);
    _workspaceOutputController.addListener(_handleWorkspaceOutputChanged);
    if (kSupabaseConfigured) {
      _authController.attachAuthListener();
    }
    _syncSessionContext();
  }

  void _handleAuthChanged() {
    _syncSessionContext();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _syncSessionContext({bool force = false}) async {
    final token = _authController.session?.accessToken;
    if (!force && token == _lastSessionAccessToken) {
      return;
    }
    _lastSessionAccessToken = token;
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _sessionMe = null;
        _loadingSessionMe = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingSessionMe = true;
      });
    }

    try {
      final me = await fetchMeV1(token);
      if (!mounted || _lastSessionAccessToken != token) {
        return;
      }
      setState(() {
        _sessionMe = me;
      });
    } on RustApiException catch (error) {
      if (_lastSessionAccessToken == token) {
        _setSharedError(error.toString());
      }
    } catch (error) {
      if (_lastSessionAccessToken == token) {
        _setSharedError(error.toString());
      }
    } finally {
      if (mounted && _lastSessionAccessToken == token) {
        setState(() {
          _loadingSessionMe = false;
        });
      }
    }
  }

  Future<void> _handleWorkspaceContextChanged() async {
    _projectsController.reset();
    _jobsController.reset();
    _taskCenterController.reset();
    _qualityReviewsController.reset();
    _workspaceOutputController.reset();
    _workspaceInputController.projectIdController.clear();
    _workspaceInputController.projectUuidController.clear();
    _workspaceInputController.clearScriptScope();
    if (mounted) {
      setState(() {
        _productScopedProjectNumericId = null;
      });
    }
    await _syncSessionContext(force: true);
    if (!mounted) {
      return;
    }
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

  void _handleShellNavigationChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleTaskCenterChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleWorkspaceOutputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleWorkspaceOperationChanged() {
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
    _workspaceOutputController.reset();
    _projectsController.reset();
    _jobsController.reset();
    _taskCenterController.reset();
    _qualityReviewsController.reset();
    _workspaceOperationController.reset();
    _productScopedProjectNumericId = null;
    _sessionMe = null;
    _lastSessionAccessToken = null;
    _loadingSessionMe = false;
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
    _shellNavigationController.removeListener(_handleShellNavigationChanged);
    _workspaceOperationController.removeListener(
      _handleWorkspaceOperationChanged,
    );
    _workspaceOutputController.removeListener(_handleWorkspaceOutputChanged);
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
    _shellNavigationController.dispose();
    _workspaceOperationController.dispose();
    _workspaceOutputController.dispose();
    _workspaceInputController.dispose();
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
