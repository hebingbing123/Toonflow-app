import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'l10n/app_localizations.dart';
import 'locale/app_locale_notifier.dart';
import 'local_prefs/risky_operation_confirm_prefs.dart';
import 'global_search/global_search_bar.dart';
import 'global_search/search_results_page.dart';
import 'navigation/search_deep_link.dart';
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
import 'project_editor/project_audit_panel.dart';
import 'project_editor/novels/support.dart';
import 'project_editor/novels/workbench_launcher.dart';
import 'project_editor/novels/events/workbench_launcher.dart';
import 'project_editor/scripts/section_builder.dart';
import 'project_editor/scripts/plan_workbench_view.dart';
import 'project_editor/scripts/plan_workbench_support.dart';
import 'project_editor/scripts/workbench/dialog_launcher.dart';
import 'project_editor/project_members_panel.dart';
import 'project_editor/short_drama_targets_panel.dart';
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
import 'admin_console/controller.dart';
import 'admin_console/section.dart';
import 'account/controller.dart';
import 'api_keys/controller.dart';
import 'content_compliance/controller.dart';
import 'content_compliance/section.dart';
import 'jobs/controller.dart';
import 'notifications/controller.dart';
import 'notifications/section.dart';
import 'projects/controller.dart';
import 'quality_reviews/controller.dart';
import 'shell/job_queue_stats_card.dart';
import 'shell/help_hub_support.dart';
import 'shell/navigation_controller.dart';
import 'shell/platform_short_drama_pipeline_strip.dart';
import 'shell/sections.dart';
import 'shell/workspace_context_view.dart';
import 'shell/outbound_webhook_event_chips.dart';
import 'skills_harness/controller.dart';
import 'overview/controller.dart';
import 'system_probes/account/controller.dart';
import 'system_probes/content/controller.dart';
import 'system_probes/models_catalog/controller.dart';
import 'task_center/controller.dart';
import 'task_center/support.dart';
import 'team_workspaces/invite_deep_link.dart';
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

bool shouldAutoOpenTeamWorkspacesForInitialUri(Uri uri) {
  final invitePrefill = resolveWorkspaceInvitePrefill(
    initialInviteToken: null,
    uriBase: uri,
  );
  return invitePrefill.shouldAutoOpenTeamWorkspace;
}

class _HomePageState extends State<HomePage> {
  String? _error;
  int? _productScopedProjectNumericId;
  MeResponse? _sessionMe;
  MeV2Response?
  _sessionMeV2; // Task 6.2: Store v2 response for workspace billing
  String? _lastSessionAccessToken;
  bool _loadingSessionMe = false;
  PlatformConfigToggleSetV1 _platformConfig =
      PlatformConfigToggleSetV1.defaults;
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

  late final AccountController _accountController = AccountController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
  );

  late final ApiKeysController _apiKeysController = ApiKeysController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
  );

  late final NotificationsController _notificationsController =
      NotificationsController(
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

  late final AdminConsoleController _adminConsoleController =
      AdminConsoleController(onErrorChanged: _setSharedError);
  late final ContentComplianceController _contentComplianceController =
      ContentComplianceController(
        accessTokenProvider: () => _session?.accessToken,
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
        onRawEvent: (event) {
          final type = event['type'];
          final payload = event['payload'];
          if (type is! String || payload is! Map<String, dynamic>) {
            return;
          }
          if (type == 'settings.notification.created' ||
              type == 'settings.notification.updated') {
            try {
              final record = NotificationRecordV1.fromJson(payload);
              _notificationsController.ingestWsNotificationEvent(record);
            } catch (_) {}
          }
        },
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
        onWsConnectionChanged: (connected) {
          _notificationsController.setRealtimeConnection(connected);
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
  Session? get _session => _authController.session;

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
    _notificationsController.addListener(_handleNotificationsChanged);
    _skillsHarnessController.addListener(_handleSkillsHarnessChanged);
    _shellNavigationController.addListener(_handleShellNavigationChanged);
    _workspaceOperationController.addListener(_handleWorkspaceOperationChanged);
    _workspaceOutputController.addListener(_handleWorkspaceOutputChanged);
    _applyInitialDeepLinkNavigation(Uri.base);
    if (kSupabaseConfigured) {
      _authController.attachAuthListener();
    }
    _syncSessionContext();
  }

  void _applyInitialDeepLinkNavigation(Uri uri) {
    final searchLink = ProductSearchDeepLink.tryParse(uri);
    if (searchLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _openGlobalSearchResults(
          searchLink.query,
          initialResultTypes: searchLink.resultTypes
              .map(_resultTypeFromWireName)
              .whereType<ResultType>()
              .toList(growable: false),
          initialTimeFrom: searchLink.timeFrom,
          initialTimeTo: searchLink.timeTo,
        );
      });
      return;
    }
    if (!shouldAutoOpenTeamWorkspacesForInitialUri(uri)) {
      return;
    }
    _shellNavigationController.selectHomeSectionMode(HomeSectionMode.product);
    _shellNavigationController.selectProductWorkspacePane(
      ProductWorkspacePane.teamWorkspaces,
    );
  }

  ResultType? _resultTypeFromWireName(String raw) {
    switch (raw) {
      case 'project':
        return ResultType.project;
      case 'script':
        return ResultType.script;
      case 'asset':
        return ResultType.asset;
      case 'novel':
        return ResultType.novel;
      case 'novel_event':
        return ResultType.novelEvent;
      default:
        return null;
    }
  }

  void _openGlobalSearchResults(
    String query, {
    List<ResultType> initialResultTypes = const <ResultType>[],
    DateTime? initialTimeFrom,
    DateTime? initialTimeTo,
  }) {
    final token = _session?.accessToken;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => SearchResultsPage(
            query: query,
            accessToken: token,
            currentWorkspaceName: _sessionMe?.currentWorkspace?.name,
            currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
            initialResultTypes: initialResultTypes,
            initialTimeFrom: initialTimeFrom,
            initialTimeTo: initialTimeTo,
            onNavigateToDetail: (type, id, {metadata}) {
              Navigator.of(context).pop();
              _handleSearchResultNavigation(type, id, metadata: metadata);
            },
          ),
        ),
      ),
    );
  }

  int? _intFromSearchMeta(dynamic v) {
    if (v == null) {
      return null;
    }
    if (v is int) {
      return v;
    }
    if (v is num) {
      return v.toInt();
    }
    return int.tryParse(v.toString());
  }

  /// 全局搜索命中后：回到产品壳并尽量恢复项目 / 剧本上下文（平台级深链）。
  void _handleSearchResultNavigation(
    ResultType type,
    String id, {
    Map<String, dynamic>? metadata,
  }) {
    if (!mounted) {
      return;
    }
    _shellNavigationController.selectHomeSectionMode(HomeSectionMode.product);

    final projectNumeric = _intFromSearchMeta(metadata?['project_numeric_id']);
    final projectUuid = metadata?['project_id']?.toString();
    final workspaceId = metadata?['workspace_id']?.toString();
    final scriptNumeric = _intFromSearchMeta(metadata?['script_numeric_id']);

    void goProjectsScoped() {
      if (projectNumeric != null && projectNumeric > 0) {
        setState(() {
          _productScopedProjectNumericId = projectNumeric;
        });
        _workspaceInputController.applyProjectScope(
          projectNumeric,
          projectUuid: projectUuid,
          workspaceId: workspaceId,
        );
      }
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.projects,
      );
    }

    switch (type) {
      case ResultType.project:
        if (projectNumeric != null && projectNumeric > 0) {
          setState(() {
            _productScopedProjectNumericId = projectNumeric;
          });
          _workspaceInputController.applyProjectScope(
            projectNumeric,
            projectUuid: id,
            workspaceId: workspaceId,
          );
        }
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.projects,
        );
        break;
      case ResultType.script:
        if (projectNumeric != null && projectNumeric > 0) {
          setState(() {
            _productScopedProjectNumericId = projectNumeric;
          });
          _workspaceInputController.applyProjectScope(
            projectNumeric,
            scriptNumericId: scriptNumeric,
            projectUuid: projectUuid,
            scriptUuid: id,
            workspaceId: workspaceId,
          );
        }
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.projects,
        );
        break;
      case ResultType.asset:
        goProjectsScoped();
        break;
      case ResultType.novel:
      case ResultType.novelEvent:
        goProjectsScoped();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == ResultType.novelEvent
                  ? '已定位到项目。请在项目详情中打开「小说与事件」查看大纲事件（事件 #${_intFromSearchMeta(metadata?['event_numeric_id']) ?? '?'}）。'
                  : '已定位到项目。请在项目详情中打开「小说与事件」查看章节（章索引 ${metadata?['chapter_index'] ?? '?'}）。',
            ),
          ),
        );
        break;
    }
  }

  void _openNotificationLink(NotificationRecordV1 notification) {
    final raw = notification.linkPath?.trim();
    if (raw == null || raw.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return;
    }
    final path = uri.path;
    if (path == '/product/search') {
      final q = uri.queryParameters['q']?.trim() ?? '';
      if (q.length >= 2) {
        _openGlobalSearchResults(q);
      }
      return;
    }
    if (path == '/product/jobs') {
      final jobId = uri.queryParameters['jobId'];
      if (jobId != null && jobId.isNotEmpty) {
        _jobsController.jobIdController.text = jobId;
        unawaited(_jobsController.fetchJobById());
      }
      _selectProductPaneWithGate(
        ProductWorkspacePane.jobs,
        disabledReason: '当前平台配置已关闭 jobs 面板，可在「平台配置」中重新开启。',
      );
      return;
    }
    if (path == '/product/team-workspaces') {
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.teamWorkspaces,
      );
      return;
    }
    if (path == '/product/platform-status') {
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.platformStatus,
      );
      return;
    }
    if (path == '/product/projects') {
      final projectNumericId = int.tryParse(
        uri.queryParameters['projectNumericId'] ?? '',
      );
      if (projectNumericId != null) {
        setState(() {
          _productScopedProjectNumericId = projectNumericId;
        });
        _workspaceInputController.applyProjectScope(projectNumericId);
      }
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.projects,
      );
      return;
    }
    if (path == '/product/content-compliance') {
      final escalationStage = uri.queryParameters['escalationStage']?.trim();
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.contentCompliance,
      );
      if (escalationStage != null && escalationStage.isNotEmpty) {
        unawaited(
          _contentComplianceController.applyQueueFilters(
            status: _contentComplianceController.queueStatusFilter,
            category: _contentComplianceController.queueCategoryFilter,
            targetType: _contentComplianceController.queueTargetTypeFilter,
            workspaceId: _contentComplianceController.queueWorkspaceIdFilter,
            workspaceName:
                _contentComplianceController.queueWorkspaceNameFilter,
            claimedByLabel:
                _contentComplianceController.queueClaimedByLabelFilter,
            slaBucket: _contentComplianceController.queueSlaBucketFilter,
            escalationStage: escalationStage,
            claimedOnly: _contentComplianceController.queueClaimedOnly,
          ),
        );
      }
      return;
    }
    if (path == '/product/platform-status') {
      _selectProductPaneWithGate(
        ProductWorkspacePane.platformStatus,
        disabledReason: '当前平台配置已关闭平台状态入口，可在「平台配置」中重新开启。',
      );
      return;
    }
    if (path == '/product/quality') {
      _selectProductPaneWithGate(
        ProductWorkspacePane.quality,
        disabledReason: '当前平台配置已关闭质量主面板，可在「平台配置」中重新开启。',
      );
      return;
    }
    if (path == '/product/help') {
      _selectProductPaneWithGate(
        ProductWorkspacePane.helpHub,
        disabledReason: '当前平台配置已关闭帮助 Hub，可在「平台配置」中重新开启。',
      );
      return;
    }
    if (path == '/product/benchmark') {
      _selectProductPaneWithGate(
        ProductWorkspacePane.benchmark,
        disabledReason: '当前平台配置已关闭评测基线入口，可在「平台配置」中重新开启。',
      );
      return;
    }
    if (path == '/product/workspace-activity') {
      _selectProductPaneWithGate(
        ProductWorkspacePane.workspaceActivity,
        disabledReason: '当前平台配置已关闭执行动态面板，可在「平台配置」中重新开启。',
      );
      return;
    }
    if (path == '/product/platform-config') {
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.platformConfig,
      );
      return;
    }
  }

  void _selectProductPaneWithGate(
    ProductWorkspacePane pane, {
    required String disabledReason,
  }) {
    if (_isProductPaneEnabledForConfig(pane, _platformConfig)) {
      _shellNavigationController.selectProductWorkspacePane(pane);
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(SnackBar(content: Text(disabledReason)));
    }
    _shellNavigationController.selectProductWorkspacePane(
      ProductWorkspacePane.platformConfig,
    );
  }

  void _handleAuthChanged() {
    _syncSessionContext();
    if (!mounted) return;
    setState(() {});
  }

  bool _isProductPaneEnabledForConfig(
    ProductWorkspacePane pane,
    PlatformConfigToggleSetV1 config,
  ) {
    switch (pane) {
      case ProductWorkspacePane.helpHub:
        return config.helpHubEnabled;
      case ProductWorkspacePane.platformStatus:
        return config.platformStatusEnabled;
      case ProductWorkspacePane.workspaceActivity:
        return config.workspaceActivityEnabled;
      case ProductWorkspacePane.benchmark:
        return config.benchmarkPaneEnabled;
      case ProductWorkspacePane.jobs:
        return config.jobsPaneEnabled;
      case ProductWorkspacePane.quality:
        return config.qualityDashboardEnabled;
      default:
        return true;
    }
  }

  void _applyPlatformConfig(PlatformConfigToggleSetV1 config) {
    _platformConfig = config;
    final currentPane = _shellNavigationController.productWorkspacePane;
    if (_isProductPaneEnabledForConfig(currentPane, config)) {
      return;
    }
    _shellNavigationController.selectProductWorkspacePane(
      ProductWorkspacePane.platformConfig,
    );
  }

  Future<void> _syncSessionContext({bool force = false}) async {
    final token = _authController.session?.accessToken;
    if (!force && token == _lastSessionAccessToken) {
      return;
    }
    _lastSessionAccessToken = token;
    if (token == null) {
      _skillsHarnessController.stopAutoSessionWs();
      if (!mounted) return;
      setState(() {
        _sessionMe = null;
        _sessionMeV2 = null; // Task 6.2: Clear v2 response
        _loadingSessionMe = false;
        _platformConfig = PlatformConfigToggleSetV1.defaults;
      });
      _notificationsController.reset();
      return;
    }

    if (mounted) {
      setState(() {
        _loadingSessionMe = true;
      });
    }

    try {
      final me = await fetchMeV1(token);
      // Task 6.2 & 6.3: Fetch v2 response for workspace billing display (feature flag gated)
      MeV2Response? meV2;
      if (kEnableWorkspaceBilling) {
        try {
          meV2 = await fetchMeV2(token);
        } catch (_) {
          // V2 might not be available yet; fall back to v1 only
        }
      }
      PlatformConfigToggleSetV1 platformConfig =
          PlatformConfigToggleSetV1.defaults;
      try {
        final platformConfigResponse = await fetchPlatformConfigV1(token);
        platformConfig = platformConfigResponse.effective;
      } catch (_) {}
      if (!mounted || _lastSessionAccessToken != token) {
        return;
      }
      setState(() {
        _sessionMe = me;
        _sessionMeV2 = meV2;
        _applyPlatformConfig(platformConfig);
      });
      unawaited(_notificationsController.prime());
      unawaited(_skillsHarnessController.startAutoSessionWs());
    } on RustApiException catch (error) {
      if (_lastSessionAccessToken == token) {
        reportRustApiError(
          error,
          onErrorChanged: _setSharedError,
          showGlobalSnackBar: false,
        );
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
    _notificationsController.reset();
    _taskCenterController.reset();
    _qualityReviewsController.reset();
    _workspaceOutputController.reset();
    _workspaceInputController.projectIdController.clear();
    _workspaceInputController.projectUuidController.clear();
    _workspaceInputController.workspaceUuidController.clear();
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

  void _handleNotificationsChanged() {
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
    _skillsHarnessController.stopAutoSessionWs();
    await _skillsHarnessController.closeChannel();
    _accountProbesController.reset();
    _contentProbesController.reset();
    _modelsCatalogController.reset();
    _overviewController.reset();
    _skillsHarnessController.reset();
    _workspaceOutputController.reset();
    _projectsController.reset();
    _jobsController.reset();
    _accountController.reset();
    _apiKeysController.reset();
    _notificationsController.reset();
    _taskCenterController.reset();
    _qualityReviewsController.reset();
    _workspaceOperationController.reset();
    _productScopedProjectNumericId = null;
    _sessionMe = null;
    _sessionMeV2 = null; // Task 6.2: Clear v2 response
    _lastSessionAccessToken = null;
    _loadingSessionMe = false;
    _platformConfig = PlatformConfigToggleSetV1.defaults;
  }

  Future<void> _handleAccountDeleted(AccountDeleteResponseV1 response) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    await _handleSignedOut();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '账号已删除：workspace ${response.ownedWorkspaceCount} · '
          'project ${response.ownedProjectCount} · '
          'job ${response.generationJobCount}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authController.removeListener(_handleAuthChanged);
    _accountProbesController.removeListener(_handleAccountProbesChanged);
    _contentProbesController.removeListener(_handleContentProbesChanged);
    _modelsCatalogController.removeListener(_handleModelsCatalogChanged);
    _overviewController.removeListener(_handleOverviewChanged);
    _taskCenterController.removeListener(_handleTaskCenterChanged);
    _notificationsController.removeListener(_handleNotificationsChanged);
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
    _accountController.dispose();
    _apiKeysController.dispose();
    _projectsController.dispose();
    _jobsController.dispose();
    _notificationsController.dispose();
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
      appBar: AppBar(
        title: const Text('OpenFlow'),
        actions: [
          // Global Search Bar
          if (session != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlobalSearchBar(
                accessToken: session.accessToken,
                currentWorkspaceName: _sessionMe?.currentWorkspace?.name,
                currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
                onNavigateToResults: _openGlobalSearchResults,
              ),
            ),
          const RiskyOperationConfirmPrefsOverflowMenu(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: _buildHomePageSections(context, session),
      ),
    );
  }
}
