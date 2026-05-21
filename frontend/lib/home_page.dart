import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'l10n/app_localizations.dart';
import 'l10n/studio_code_labels.dart';
import 'l10n/short_video_generation_blocked.dart';
import 'l10n/short_video_readiness_localized.dart';
import 'locale/app_locale_notifier.dart';
import 'local_prefs/risky_operation_confirm_prefs.dart';
import 'global_search/global_search_bar.dart';
import 'global_search/search_results_page.dart';
import 'navigation/search_deep_link.dart';
import 'project_editor/assets/clip_upload_launcher.dart';
import 'project_editor/assets/dialogs/candidate_status_dialog.dart';
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
import 'project_editor/step_model_routing_section.dart';
import 'project_editor/style_pack_catalog.dart';
import 'project_editor/style_pack_picker_field.dart';
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
import 'notifications/product_scope.dart';
import 'notifications/section.dart';
import 'projects/controller.dart';
import 'quality_reviews/controller.dart';
import 'shell/job_queue_stats_card.dart';
import 'shell/help_hub_support.dart';
import 'shell/home_shell_mode.dart';
import 'shell/navigation_controller.dart';
import 'design_system/components/openflow_brand.dart';
import 'design_system/components/studio_model_cost_controls.dart';
import 'design_system/ix/studio_cost_confirm_sheet.dart';
import 'design_system/components/studio_dropdown_field.dart';
import 'design_system/components/studio_empty_state.dart';
import 'design_system/components/studio_onboarding_coach.dart';
import 'design_system/components/studio_pane_header.dart';
import 'design_system/components/studio_shell_backdrop.dart';
import 'design_system/components/studio_surfaces.dart';
import 'design_system/components/studio_workbench_section.dart';
import 'design_system/components/studio_text_styles.dart';
import 'design_system/glass.dart';
import 'design_system/ix/studio_api_error_callout.dart';
import 'design_system/ix/studio_command_palette.dart';
import 'design_system/ix/studio_job_tray.dart';
import 'design_system/ix/studio_snackbar.dart';
import 'design_system/tokens.dart';
import 'product_shell/login_page.dart';
import 'settings/model_vendors/domestic_vendor_setup_prefs.dart';
import 'settings/model_vendors/domestic_vendors.dart';
import 'settings/model_vendors/vendor_setup_loader.dart';
import 'product_shell/navigation.dart';
import 'product_shell/studio_shell_header.dart';
import 'product_shell/studio_shell_layout.dart';
import 'product_shell/studio_app_bar_actions.dart';
import 'product_shell/studio_pipeline_strip.dart';
import 'product_shell/studio_shell_branches.dart';
import 'product_shell/product_studio_route_launcher.dart';
import 'product_shell/studio_shell_scope.dart';
import 'product_shell/studio_shell_navigation.dart';
import 'product_shell/studio_theme.dart';
import 'studio/default_project_scope.dart';
import 'studio/recent_projects_prefs.dart';
import 'studio/job_scope.dart';
import 'project_studio/project_studio_host.dart';
import 'project_studio/studio_overlay_children.dart';
import 'project_studio/studio_overlay_resolution.dart';
import 'project_studio/project_studio_scope.dart';
import 'project_studio/studio_review_pack_scope.dart';
import 'project_studio/studio_snapshot_bus.dart';
import 'project_studio/studio_merge_deliver_bar.dart';
import 'project_studio/studio_overlay_mode.dart';
import 'project_studio/studio_step.dart';
import 'project_studio/studio_video_step_panel.dart';
import 'project_studio/script_step_panel.dart';
import 'project_studio/novel_crawl_auth_section.dart';
import 'project_studio/art_step_panel.dart';
import 'product_shell/studio_agent_drawer.dart';
import 'episode_console/episode_console_page.dart';
import 'storyboard_studio/storyboard_studio_page.dart';
import 'product_shell/settings_hub_page.dart';
import 'shell/platform_short_drama_pipeline_strip.dart';
import 'shell/product_scope_label.dart';
import 'shell/sections.dart';
import 'shell/workspace_context_view.dart';
import 'shell/outbound_webhook_event_chips.dart';
import 'skills_harness/controller.dart';
import 'overview/controller.dart';
import 'system_probes/account/controller.dart';
import 'system_probes/content/controller.dart';
import 'system_probes/models_catalog/controller.dart';
import 'system_probes/models_catalog/production_probe_scope.dart';
import 'task_center/controller.dart';
import 'task_center/support.dart';
import 'team_workspaces/invite_deep_link.dart';
import 'rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

part 'project_editor/editor.dart';
part 'project_editor/editor_dialog_basics.dart';
part 'project_editor/editor_dialog_content.dart';
part 'project_editor/editor_dialog_content_novels.dart';
part 'project_editor/editor_dialog_content_assets.dart';
part 'project_editor/editor_dialog_content_scripts.dart';
part 'project_editor/editor_dialog_actions.dart';
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
part 'project_editor/assets/compatibility/crud_primary.dart';
part 'project_editor/assets/compatibility/crud_query.dart';
part 'project_editor/assets/compatibility/relations.dart';
part 'project_editor/assets/compatibility/images.dart';
part 'project_editor/assets/compatibility/images_actions.dart';
part 'project_editor/assets/compatibility/images_crud_actions.dart';
part 'project_editor/assets/compatibility/images_workbench_actions.dart';
part 'project_editor/novels/compatibility/section.dart';
part 'project_editor/novels/compatibility/actions.dart';
part 'project_editor/novels/compatibility/actions_probe_reads.dart';
part 'project_editor/novels/compatibility/actions_probe_mutations.dart';
part 'project_editor/http_probes/general_probe.dart';
part 'project_editor/http_probes/project_probe.dart';
part 'project_editor/http_probes/tasks_probe.dart';
part 'project_editor/scripts/plan_workbench.dart';
part 'project_editor/scripts/probe/actions.dart';
part 'project_editor/scripts/dialogs/batch_add.dart';
part 'script_editor/storyboards/dialogs/add.dart';
part 'script_editor/storyboards/dialogs/batch_add.dart';
part 'script_editor/storyboards/workbench.dart';
part 'system_probes/controller.dart';
part 'system_probes/models_catalog/settings_probe.dart';
part 'system_probes/models_catalog/settings_probe_scope.dart';
part 'system_probes/models_catalog/settings_probe_core.dart';
part 'system_probes/models_catalog/settings_probe_vendor_assets.dart';
part 'system_probes/models_catalog/production_probe.dart';
part 'system_probes/models_catalog/production_probe_typed.dart';
part 'shell/build_sections.dart';
part 'shell/build_sections_product.dart';
part 'shell/product_scope_management.dart';
part 'shell/product_navigation.dart';
part 'shell/product_studio_overlay.dart';
part 'shell/product_studio_steps.dart';
part 'shell/product_workbench_launchers.dart';
part 'shell/product_agent_workspace.dart';
part 'shell/product_panes_builder.dart';
part 'shell/product_pane_selector_section.dart';
part 'shell/platform_config_section.dart';
part 'shell/help_hub_section.dart';
part 'shell/help_hub_docs_panel.dart';
part 'shell/help_hub_webhooks_panel.dart';
part 'shell/help_hub_billing_panel.dart';
part 'shell/build_product_shell.dart';
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
part 'storyboard_editor/character_section.dart';
part 'storyboard_editor/video_section.dart';
part 'storyboard_editor/actions/character_helpers.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.shellMode = HomeShellMode.harness,
    this.initialProductPane,
    this.navigationShell,
    this.studioOverlay = StudioOverlayMode.none,
    this.studioProjectNumericId,
    this.studioStepSlug,
    this.studioScriptNumericId,
    this.debugAuthenticatedAccessToken,
    this.debugSkipSessionContextSync = false,
    this.debugSkipAuthListenerAttach = false,
    this.debugStudioProjectUuid,
    this.debugStudioProjectName,
    this.debugProjectStudioSnapshotLoader,
    this.debugHelpHubWebhooks,
    this.debugHelpHubLatestCreatedWebhook,
    this.debugHelpHubBillingEventsPage,
    this.debugHelpHubWebhookDeliveries,
    this.debugHelpHubWebhookLastTestResults,
  });

  /// [HomeShellMode.product] = studio sidebar + login gate ([waoowaoo]-style).
  final HomeShellMode shellMode;

  /// Initial studio pane when using [go_router] deep links.
  final ProductWorkspacePane? initialProductPane;

  /// When set, primary rail uses [StatefulShellRoute] (URL updates without remounting).
  final StatefulNavigationShell? navigationShell;

  final StudioOverlayMode studioOverlay;
  final int? studioProjectNumericId;
  final String? studioStepSlug;
  final int? studioScriptNumericId;

  /// Narrow testing seam for widget tests that need the authenticated shell
  /// without initializing a real Supabase session.
  final String? debugAuthenticatedAccessToken;

  /// When true, skips `/me` and platform-config fetches during session sync.
  final bool debugSkipSessionContextSync;

  /// When true, avoids touching `Supabase.instance` during widget tests.
  final bool debugSkipAuthListenerAttach;

  /// Optional project UUID fallback for project-studio widget tests.
  final String? debugStudioProjectUuid;

  /// Optional project name fallback for project-studio widget tests.
  final String? debugStudioProjectName;

  /// Optional readiness loader override for project-studio widget tests.
  final ProjectStudioReadinessLoader? debugProjectStudioSnapshotLoader;

  /// Optional help-hub webhook seed for widget tests.
  final OutboundWebhookListResponseV1? debugHelpHubWebhooks;

  /// Optional latest-created webhook banner seed for widget tests.
  final OutboundWebhookCreatedResponseV1? debugHelpHubLatestCreatedWebhook;

  /// Optional billing webhook audit seed for widget tests.
  final BillingWebhookEventsResponseV1? debugHelpHubBillingEventsPage;

  /// Optional per-webhook delivery log seeds for widget tests.
  final Map<String, OutboundWebhookDeliveryListResponseV1>?
  debugHelpHubWebhookDeliveries;

  /// Optional per-webhook test result seeds for widget tests.
  final Map<String, OutboundWebhookTestResponseV1>?
  debugHelpHubWebhookLastTestResults;

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
  AppLocalizations? _appL10n;
  int? _productScopedProjectNumericId;
  List<String> _recentProjectIds = const <String>[];
  ShortVideoSpaceInitialFocus _shortVideoSpaceInitialFocus =
      ShortVideoSpaceInitialFocus.none;
  bool _pendingStudioNovelWorkbench = false;
  int? _pendingStudioAssetNumericId;
  MeResponse? _sessionMe;
  MeV2Response?
  _sessionMeV2; // Task 6.2: Store v2 response for workspace billing
  String? _lastSessionAccessToken;
  bool _loadingSessionMe = false;
  int _settingsHubInitialTabIndex = 0;
  bool _vendorSetupSnackShown = false;
  PlatformConfigToggleSetV1 _platformConfig =
      PlatformConfigToggleSetV1.defaults;
  Listenable? _studioRouteListenerTarget;
  final _workspaceInputController = WorkspaceInputController();
  bool _workspacePromptDefaultsSeeded = false;
  final _workspaceOperationController = WorkspaceOperationController();
  late final WorkspaceRunController _workspaceRunController =
      WorkspaceRunController(
        inputController: _workspaceInputController,
        operationController: _workspaceOperationController,
        outputController: _workspaceOutputController,
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
        clearWsLog: _skillsHarnessController.wsLog.clear,
        resetWorkspaceOutputs: () {
          _workspaceOutputController.reset();
        },
        requestSender: _sendWorkspaceHarnessMessages,
      );

  late final ProjectsController _projectsController = ProjectsController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
    l10nProvider: () => _appL10n,
  );

  late final JobsController _jobsController = JobsController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
    l10nProvider: () => _appL10n,
    onJobScopeResolved: (scope) {
      if (!scope.hasProjectScope) {
        return;
      }
      if (mounted) {
        setState(() {
          _productScopedProjectNumericId = scope.projectNumericId;
        });
      } else {
        _productScopedProjectNumericId = scope.projectNumericId;
      }
      _workspaceInputController.applyProjectScopeRef(
        projectNumericId: scope.projectNumericId,
        scriptNumericId: scope.scriptNumericId,
        projectUuid: scope.projectUuid,
        scriptUuid: scope.scriptUuid,
        workspaceId: scope.workspaceId,
      );
    },
  );

  late final AccountController _accountController = AccountController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
    l10nProvider: () => _appL10n,
  );

  late final ApiKeysController _apiKeysController = ApiKeysController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
    l10nProvider: () => _appL10n,
  );

  late final NotificationsController _notificationsController =
      NotificationsController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
      );

  late final TaskCenterController _taskCenterController = TaskCenterController(
    accessTokenProvider: () => _session?.accessToken,
    onErrorChanged: _setSharedError,
    l10nProvider: () => _appL10n,
    projectIdTextProvider: () =>
        _workspaceInputController.projectIdController.text,
    projectUuidTextProvider: () =>
        _workspaceInputController.projectUuidController.text,
  );

  late final QualityReviewsController _qualityReviewsController =
      QualityReviewsController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
      );

  late final OverviewController _overviewController = OverviewController(
    onErrorChanged: _setSharedError,
    l10nProvider: () => _appL10n,
  );

  late final AdminConsoleController _adminConsoleController =
      AdminConsoleController(
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
      );
  late final ContentComplianceController _contentComplianceController =
      ContentComplianceController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
      );

  late final AccountProbesController _accountProbesController =
      AccountProbesController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
        projectIdTextProvider: () =>
            _workspaceInputController.projectIdController.text,
        projectUuidTextProvider: () =>
            _workspaceInputController.projectUuidController.text,
        scriptIdTextProvider: () =>
            _workspaceInputController.scriptIdController.text,
      );

  late final ContentProbesController _contentProbesController =
      ContentProbesController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
      );

  late final ModelsCatalogController _modelsCatalogController =
      ModelsCatalogController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
        runSettingsAndAssetsProbes: _runModelsCatalogSettingsAndAssetsProbes,
        runProductionProbes: _runModelsCatalogProductionProbes,
        formatProbeStatusMap: _formatProbeStatusMap,
      );

  late final AuthController _authController = AuthController(
    onErrorChanged: _setSharedError,
    onSignedOut: _handleSignedOut,
    l10nProvider: () => _appL10n,
  );

  late final ShellNavigationController _shellNavigationController =
      ShellNavigationController();
  late final WorkspaceOutputController _workspaceOutputController =
      WorkspaceOutputController(l10nProvider: () => _appL10n);
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
        l10nProvider: () => _appL10n,
      );

  late final SkillsHarnessController _skillsHarnessController =
      SkillsHarnessController(
        accessTokenProvider: () => _session?.accessToken,
        onErrorChanged: _setSharedError,
        l10nProvider: () => _appL10n,
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
  Session? get _session {
    if (widget.debugSkipAuthListenerAttach &&
        (widget.debugAuthenticatedAccessToken?.trim().isNotEmpty ?? false)) {
      return null;
    }
    return _authController.session;
  }

  String? get _effectiveAccessToken {
    final injected = widget.debugAuthenticatedAccessToken?.trim();
    if (injected != null && injected.isNotEmpty) {
      return injected;
    }
    return _session?.accessToken;
  }

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
    void apply() {
      if (!mounted) return;
      if (_error == error) return;
      setState(() {
        _error = error;
      });
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      apply();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    }
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
    _projectsController.addListener(_handleProjectsControllerChanged);
    _workspaceOperationController.addListener(_handleWorkspaceOperationChanged);
    _workspaceOutputController.addListener(_handleWorkspaceOutputChanged);
    _applyInitialDeepLinkNavigation(Uri.base);
    if (widget.shellMode == HomeShellMode.product) {
      _shellNavigationController.selectHomeSectionMode(HomeSectionMode.product);
      _shellNavigationController.selectProductWorkspacePane(
        widget.initialProductPane ?? ProductWorkspacePane.projects,
      );
      if (widget.studioProjectNumericId != null) {
        _productScopedProjectNumericId = widget.studioProjectNumericId;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _attachStudioRouteListener();
        _syncStudioPaneFromRoute();
        unawaited(_refreshRecentProjectIds());
      });
    }
    if (kSupabaseConfigured && !widget.debugSkipAuthListenerAttach) {
      _authController.attachAuthListener();
    }
    _syncSessionContext();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    if (widget.studioProjectNumericId != oldWidget.studioProjectNumericId &&
        widget.studioProjectNumericId != null) {
      _productScopedProjectNumericId = widget.studioProjectNumericId;
    }
    if (oldWidget.navigationShell != widget.navigationShell ||
        oldWidget.studioOverlay != widget.studioOverlay ||
        oldWidget.initialProductPane != widget.initialProductPane) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _attachStudioRouteListener();
        if (widget.studioOverlay == StudioOverlayMode.none) {
          if (GoRouter.maybeOf(context) != null) {
            _syncStudioPaneFromRoute();
          } else if (widget.initialProductPane != null &&
              _shellNavigationController.productWorkspacePane !=
                  widget.initialProductPane) {
            _shellNavigationController.replaceProductWorkspacePane(
              widget.initialProductPane!,
            );
          }
          return;
        }
        if (widget.initialProductPane != null &&
            _shellNavigationController.productWorkspacePane !=
                widget.initialProductPane) {
          _shellNavigationController.replaceProductWorkspacePane(
            widget.initialProductPane!,
          );
        }
      });
    }
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
    final token = _effectiveAccessToken;
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

  /// After a global search hit: return to the product shell and restore project/script context when possible (platform deep link).
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
      if ((projectNumeric != null && projectNumeric > 0) ||
          (projectUuid != null && projectUuid.isNotEmpty)) {
        setState(() {
          _productScopedProjectNumericId =
              projectNumeric != null && projectNumeric > 0
              ? projectNumeric
              : null;
        });
      }
      if ((projectNumeric != null && projectNumeric > 0) ||
          (projectUuid != null && projectUuid.isNotEmpty)) {
        _workspaceInputController.applyProjectScopeRef(
          projectNumericId: projectNumeric,
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
        if ((projectNumeric != null && projectNumeric > 0) ||
            id.trim().isNotEmpty) {
          setState(() {
            _productScopedProjectNumericId =
                projectNumeric != null && projectNumeric > 0
                ? projectNumeric
                : null;
          });
        }
        if (id.trim().isNotEmpty ||
            (projectNumeric != null && projectNumeric > 0)) {
          _workspaceInputController.applyProjectScopeRef(
            projectNumericId: projectNumeric,
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
          _workspaceInputController.applyProjectScopeRef(
            projectNumericId: projectNumeric,
            scriptNumericId: scriptNumeric,
            projectUuid: projectUuid,
            scriptUuid: id,
            workspaceId: workspaceId,
          );
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.projects,
          );
          context.go('/projects/$projectNumeric/${StudioStep.script.slug}');
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.globalSearchScriptStudioNavigated)),
            );
          }
        } else {
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.projects,
          );
        }
        break;
      case ResultType.asset:
        final assetNumeric =
            _intFromSearchMeta(metadata?['numeric_id']) ??
            _intFromSearchMeta(metadata?['asset_numeric_id']) ??
            int.tryParse(id);
        if (projectNumeric != null && projectNumeric > 0) {
          setState(() {
            _productScopedProjectNumericId = projectNumeric;
            _pendingStudioAssetNumericId = assetNumeric;
          });
          _workspaceInputController.applyProjectScopeRef(
            projectNumericId: projectNumeric,
            projectUuid: projectUuid,
            workspaceId: workspaceId,
          );
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.projects,
          );
          context.go('/projects/$projectNumeric/${StudioStep.assets.slug}');
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.globalSearchAssetStudioNavigated(
                    '${assetNumeric ?? id}',
                  ),
                ),
              ),
            );
          }
        } else {
          goProjectsScoped();
        }
        break;
      case ResultType.novel:
      case ResultType.novelEvent:
        if (projectNumeric != null && projectNumeric > 0) {
          setState(() {
            _productScopedProjectNumericId = projectNumeric;
            _pendingStudioNovelWorkbench = true;
          });
          _workspaceInputController.applyProjectScopeRef(
            projectNumericId: projectNumeric,
            projectUuid: projectUuid,
            workspaceId: workspaceId,
          );
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.projects,
          );
          context.go('/projects/$projectNumeric/${StudioStep.script.slug}');
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.globalSearchNovelStudioNavigated)),
            );
          }
        } else {
          goProjectsScoped();
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  type == ResultType.novelEvent
                      ? l10n.globalSearchNovelEventNavigated(
                          '${_intFromSearchMeta(metadata?['event_numeric_id']) ?? '?'}',
                        )
                      : l10n.globalSearchNovelChapterNavigated(
                          '${metadata?['chapter_index'] ?? '?'}',
                        ),
                ),
              ),
            );
          }
        }
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
    final scope = resolveNotificationProductScope(notification, uri);

    void applyNotificationProjectScope() {
      if (!scope.hasProjectScope) {
        return;
      }
      setState(() {
        _productScopedProjectNumericId = scope.projectNumericId;
      });
      _workspaceInputController.applyProjectScopeRef(
        projectNumericId: scope.projectNumericId,
        scriptNumericId: scope.scriptNumericId,
        projectUuid: scope.projectUuid,
        workspaceId: scope.workspaceId,
      );
    }

    if (path == '/product/search') {
      final q = uri.queryParameters['q']?.trim() ?? '';
      if (q.length >= 2) {
        _openGlobalSearchResults(q);
      }
      return;
    }
    if (path == '/product/jobs') {
      applyNotificationProjectScope();
      final jobId = uri.queryParameters['jobId'];
      if (jobId != null && jobId.isNotEmpty) {
        _jobsController.jobIdController.text = jobId;
        unawaited(_jobsController.fetchJobById());
      }
      _selectProductPaneWithGate(
        ProductWorkspacePane.jobs,
        disabledReason: resolveAppLocalizationsForErrors(
          context,
        ).productPaneDisabledJobs,
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
      applyNotificationProjectScope();
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
        disabledReason: AppLocalizations.of(
          context,
        )!.productPaneDisabledPlatformStatus,
      );
      return;
    }
    if (path == '/product/quality') {
      applyNotificationProjectScope();
      _selectProductPaneWithGate(
        ProductWorkspacePane.quality,
        disabledReason: AppLocalizations.of(
          context,
        )!.productPaneDisabledQuality,
      );
      return;
    }
    if (path == '/product/tasks') {
      applyNotificationProjectScope();
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.tasks,
      );
      return;
    }
    if (path == '/product/help') {
      _selectProductPaneWithGate(
        ProductWorkspacePane.helpHub,
        disabledReason: AppLocalizations.of(
          context,
        )!.productPaneDisabledHelpHub,
      );
      return;
    }
    if (path == '/product/benchmark') {
      _selectProductPaneWithGate(
        ProductWorkspacePane.benchmark,
        disabledReason: AppLocalizations.of(
          context,
        )!.productPaneDisabledBenchmark,
      );
      return;
    }
    if (path == '/product/workspace-activity') {
      _selectProductPaneWithGate(
        ProductWorkspacePane.workspaceActivity,
        disabledReason: AppLocalizations.of(
          context,
        )!.productPaneDisabledWorkspaceActivity,
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
    final token = _effectiveAccessToken;
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

    if (widget.debugSkipSessionContextSync) {
      if (!mounted) {
        return;
      }
      setState(() {
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
      if (widget.shellMode == HomeShellMode.harness) {
        unawaited(_skillsHarnessController.startAutoSessionWs());
      } else {
        unawaited(_projectsController.loadProjects());
        _ensureProductPaneData(_shellNavigationController.productWorkspacePane);
        unawaited(_maybeNudgeDomesticVendorSetup(token));
      }
    } catch (error) {
      if (_lastSessionAccessToken != token) {
        return;
      }
      if (mounted) {
        reportRustOrDescribeApiError(
          error,
          onErrorChanged: _setSharedError,
          l10n: _appL10n ?? lookupAppLocalizations(const Locale('en')),
          showGlobalSnackBar: false,
        );
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
        _recentProjectIds = const <String>[];
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
    if (widget.shellMode == HomeShellMode.product) {
      _ensureProductPaneData(_shellNavigationController.productWorkspacePane);
    }
    setState(() {});
  }

  void _handleProjectsControllerChanged() {
    if (!mounted || widget.shellMode != HomeShellMode.product) {
      return;
    }
    if (_projectsController.projects == null) {
      return;
    }
    unawaited(_applyDefaultProductProjectScopeIfNeeded());
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
    _recentProjectIds = const <String>[];
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
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.accountDeletedSummary(
              response.ownedWorkspaceCount,
              response.ownedProjectCount,
              response.generationJobCount,
            ),
          ),
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.shellMode == HomeShellMode.product &&
        widget.studioOverlay == StudioOverlayMode.none) {
      _syncStudioPaneFromRoute();
    }
  }

  void _attachStudioRouteListener() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final target = router.routerDelegate;
    if (identical(_studioRouteListenerTarget, target)) {
      return;
    }
    _detachStudioRouteListener();
    _studioRouteListenerTarget = target;
    target.addListener(_handleStudioRouteChanged);
  }

  void _detachStudioRouteListener() {
    _studioRouteListenerTarget?.removeListener(_handleStudioRouteChanged);
    _studioRouteListenerTarget = null;
  }

  @override
  void dispose() {
    _detachStudioRouteListener();
    _authController.removeListener(_handleAuthChanged);
    _accountProbesController.removeListener(_handleAccountProbesChanged);
    _contentProbesController.removeListener(_handleContentProbesChanged);
    _modelsCatalogController.removeListener(_handleModelsCatalogChanged);
    _overviewController.removeListener(_handleOverviewChanged);
    _taskCenterController.removeListener(_handleTaskCenterChanged);
    _notificationsController.removeListener(_handleNotificationsChanged);
    _skillsHarnessController.removeListener(_handleSkillsHarnessChanged);
    _shellNavigationController.removeListener(_handleShellNavigationChanged);
    _projectsController.removeListener(_handleProjectsControllerChanged);
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
    _appL10n = AppLocalizations.of(context);
    final l10n = _appL10n;
    if (l10n != null && !_workspacePromptDefaultsSeeded) {
      _workspacePromptDefaultsSeeded = true;
      _workspaceInputController.applyLocalizedPromptDefaults(l10n);
    }
    final session = _session;
    final accessToken = _effectiveAccessToken;

    if (widget.shellMode == HomeShellMode.product) {
      return _buildProductShellScaffold(context, accessToken);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _appL10n?.appTitle ??
              lookupAppLocalizations(const Locale('en')).appTitle,
        ),
        actions: [
          if (accessToken != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlobalSearchBar(
                accessToken: accessToken,
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
