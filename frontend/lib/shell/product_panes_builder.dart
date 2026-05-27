// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

/// Product panes builder extension for _HomePageState.
/// Handles building product pane selector and active pane widgets.
extension _HomePageProductPanesBuilder on _HomePageState {
  Widget _buildFeatureGatedPane({
    required bool enabled,
    required String title,
    required String reason,
    required Widget child,
  }) {
    if (enabled) {
      return child;
    }
    return _PlatformPaneDisabledNotice(title: title, reason: reason);
  }

  Widget _buildProductPaneSelector(BuildContext context) {
    return _ProductPaneSelector(
      config: _platformConfig,
      unreadNotifications: _notificationsController.unreadCount,
      selectedPane: _shellNavigationController.productWorkspacePane,
      onSelectPane: (pane) {
        if (widget.shellMode == HomeShellMode.product) {
          _handleProductPipelinePaneSelect(pane);
        } else {
          _shellNavigationController.selectProductWorkspacePane(pane);
        }
      },
    );
  }

  Widget _buildProductScriptOrProductionPane(
    BuildContext context, {
    required AppLocalizations l10n,
    required ProductWorkspacePane pane,
    required AgentWorkspacePane agentPane,
    required StudioStep studioStep,
    required String redirectTitle,
    required IconData redirectIcon,
    required String agentTitle,
    required String agentSubtitle,
  }) {
    if (widget.shellMode != HomeShellMode.product) {
      return _buildAgentWorkspacePane(
        initialPane: agentPane,
        sectionTitle: agentTitle,
        sectionDescription: agentSubtitle,
      );
    }
    if (_isDemoModeActive && ProductDemoTour.instance.isEngaged) {
      return _buildAgentWorkspacePane(
        initialPane: agentPane,
        sectionTitle: agentTitle,
        sectionDescription: agentSubtitle,
      );
    }
    final projectId = _resolvedProductNumericIdForPipeline();
    if (projectId == null) {
      return _buildProductHarnessRedirectHint(
        context,
        title: redirectTitle,
        icon: redirectIcon,
        enterStudioStep: studioStep,
      );
    }
    return ProductStudioRouteLauncher(
      route: '/projects/$projectId/${studioStep.slug}',
    );
  }

  Widget _buildProductHarnessRedirectHint(
    BuildContext context, {
    required String title,
    required IconData icon,
    required StudioStep enterStudioStep,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final projectId = _resolvedProductNumericIdForPipeline();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        StudioPaneHeader(
          title: title,
          showBack: false,
        ),
        const SizedBox(height: 32),
        Center(
          child: StudioEmptyState(
            title: l10n.studioProductHarnessRedirectTitle,
            subtitle: l10n.studioProductHarnessRedirectSubtitle,
            icon: icon,
            actionLabel: projectId != null ? l10n.studioEnterStudio : null,
            onAction: projectId != null
                ? () =>
                      context.go('/projects/$projectId/${enterStudioStep.slug}')
                : null,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActiveProductPaneWidgets(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return <Widget>[
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.helpHub)
        _buildFeatureGatedPane(
          enabled: _platformConfig.helpHubEnabled,
          title: l10n.productNavHelp,
          reason: l10n.productPaneDisabledHelpHub,
          child: _HelpHubSection(
            accessToken: _effectiveAccessToken,
            debugWebhooks:
                widget.debugHelpHubWebhooks ??
                _activeDemoCatalog?.helpHubWebhooks,
            debugLatestCreatedWebhook:
                widget.debugHelpHubLatestCreatedWebhook ??
                _activeDemoCatalog?.helpHubLatestCreatedWebhook,
            debugBillingEventsPage:
                widget.debugHelpHubBillingEventsPage ??
                _activeDemoCatalog?.helpHubBillingEventsPage,
            debugWebhookDeliveries:
                widget.debugHelpHubWebhookDeliveries ??
                _activeDemoCatalog?.helpHubWebhookDeliveries,
            debugWebhookLastTestResults:
                widget.debugHelpHubWebhookLastTestResults ??
                _activeDemoCatalog?.helpHubWebhookLastTestResults,
          ),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.shortVideoSpace)
        _buildShortVideoSpaceSection(),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.projects)
        ProjectsSection(
          accessToken: _effectiveAccessToken,
          controller: _projectsController,
          productPresentation: widget.shellMode == HomeShellMode.product,
          currentWorkspaceName: _sessionMe?.currentWorkspace?.name,
          currentWorkspaceType: _sessionMe?.currentWorkspace?.workspaceType,
          currentProjectNumericId: _productScopedProjectNumericId,
          onOpenProjectDetail: _openProjectDetail,
          onSelectProjectScope: _selectProjectScope,
          onOpenProjectStudio: _openProjectStudio,
          onOpenModelVendorSettings: widget.shellMode == HomeShellMode.product
              ? _openSettingsModelVendorsTab
              : null,
          onOpenTeamWorkspaces: () {
            _shellNavigationController.selectProductWorkspacePane(
              ProductWorkspacePane.teamWorkspaces,
            );
          },
          onExploreDemo: _isDemoModeActive
              ? null
              : () => unawaited(
                  _enterProductDemoMode(
                    guest:
                        _effectiveAccessToken == null ||
                        _effectiveAccessToken ==
                            ProductDemoMode.guestAccessToken,
                  ),
                ),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.account)
        widget.shellMode == HomeShellMode.product
            ? SettingsHubPage(
                accountController: _accountController,
                apiKeysController: _apiKeysController,
                accessToken: _effectiveAccessToken,
                onAccountDeleted: _handleAccountDeleted,
                onWorkspaceContextChanged: _handleWorkspaceContextChanged,
                currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
                initialTabIndex: StudioSettingsHubNavigation.consumePending(
                  fallback: _settingsHubInitialTabIndex,
                ),
              )
            : AccountSection(
                controller: _accountController,
                onAccountDeleted: _handleAccountDeleted,
              ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.apiKeys)
        ApiKeysSection(controller: _apiKeysController),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.notifications)
        NotificationsSection(
          controller: _notificationsController,
          onOpenNotification: _openNotificationLink,
          studioPresentation: widget.shellMode == HomeShellMode.product,
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.contentCompliance)
        ContentComplianceSection(
          controller: _contentComplianceController,
          onOpenTarget: _openComplianceProductTarget,
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.platformStatus)
        _buildFeatureGatedPane(
          enabled: _platformConfig.platformStatusEnabled,
          title: l10n.productNavPlatformStatus,
          reason: l10n.productPaneDisabledPlatformStatus,
          child: PlatformStatusSection(
            debugSnapshot: _activeDemoCatalog?.platformStatusSnapshot,
            onOverallHealthChanged: (healthy, degradedEndpoints) {
              _notificationsController.addPlatformStatusTransitionNotification(
                healthy: healthy,
                degradedEndpoints: degradedEndpoints,
              );
            },
          ),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.teamWorkspaces)
        TeamWorkspacesSection(
          accessToken: _effectiveAccessToken,
          debugInitialItems: _activeDemoCatalog?.workspaceListItems,
          onWorkspaceContextChanged: _handleWorkspaceContextChanged,
          currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.scriptWorkspace)
        _buildProductScriptOrProductionPane(
          context,
          l10n: l10n,
          pane: ProductWorkspacePane.scriptWorkspace,
          agentPane: AgentWorkspacePane.script,
          studioStep: StudioStep.script,
          redirectTitle: l10n.productNavScriptWorkspace,
          redirectIcon: Icons.menu_book_outlined,
          agentTitle: l10n.productAgentScriptWorkspaceTitle,
          agentSubtitle: l10n.productAgentScriptWorkspaceSubtitle,
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.productionWorkspace)
        _buildProductScriptOrProductionPane(
          context,
          l10n: l10n,
          pane: ProductWorkspacePane.productionWorkspace,
          agentPane: AgentWorkspacePane.production,
          studioStep: StudioStep.storyboard,
          redirectTitle: l10n.productNavProductionWorkspace,
          redirectIcon: Icons.theaters_outlined,
          agentTitle: l10n.productAgentProductionWorkspaceTitle,
          agentSubtitle: l10n.productAgentProductionWorkspaceSubtitle,
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.workspaceActivity)
        _buildFeatureGatedPane(
          enabled: _platformConfig.workspaceActivityEnabled,
          title: l10n.productNavWorkspaceActivity,
          reason: l10n.productPaneDisabledWorkspaceActivity,
          child: _buildAgentWorkspacePane(
            initialPane: AgentWorkspacePane.activity,
            sectionTitle: l10n.productAgentActivityTitle,
            sectionDescription: l10n.productAgentActivitySubtitle,
          ),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.benchmark)
        _buildFeatureGatedPane(
          enabled: _platformConfig.benchmarkPaneEnabled,
          title: l10n.productNavBenchmark,
          reason: l10n.productPaneDisabledBenchmark,
          child: BenchmarkSection(
            accessToken: _effectiveAccessToken,
            debugSnapshot: _activeDemoCatalog?.benchmarkSnapshot,
            demoMode: _isDemoModeActive,
          ),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.tasks)
        TaskCenterSection(
          studioPresentation: widget.shellMode == HomeShellMode.product,
          accessToken: _effectiveAccessToken,
          initialProjectNumericId: _productScopedProjectNumericId,
          initialProjectUuid:
              _workspaceInputController.projectUuidController.text
                  .trim()
                  .isEmpty
              ? null
              : _workspaceInputController.projectUuidController.text.trim(),
          onNavigateExportJobDeepLink: (TaskCenterExportJobDeepLink link) {
            if (link.projectNumericId != null || link.projectUuid != null) {
              setState(() {
                _productScopedProjectNumericId = link.projectNumericId;
              });
            }
            _workspaceInputController.applyProjectScopeRef(
              projectNumericId: link.projectNumericId,
              scriptNumericId: link.scriptNumericId,
              projectUuid: link.projectUuid,
              workspaceId: link.workspaceId,
            );
            if (widget.shellMode == HomeShellMode.product &&
                link.projectNumericId != null &&
                link.projectNumericId! > 0) {
              final step = link.openProductionWorkspace
                  ? StudioStep.storyboard.slug
                  : StudioStep.script.slug;
              context.go('/projects/${link.projectNumericId}/$step');
            } else {
              _shellNavigationController.selectProductWorkspacePane(
                link.openProductionWorkspace
                    ? ProductWorkspacePane.productionWorkspace
                    : ProductWorkspacePane.scriptWorkspace,
              );
            }
          },
          onNavigateDomainDeepLink: (TaskCenterDomainDeepLink link) {
            _applyDomainDeepLink(link);
          },
          loadingTaskProjects: _taskCenterController.loadingTaskProjects,
          loadingTaskCategories: _taskCenterController.loadingTaskCategories,
          loadingTaskApi: _taskCenterController.loadingTaskApi,
          loadingTaskDetailsByNumericId:
              _taskCenterController.loadingTaskDetailsByNumericId,
          loadingTaskDetailsUuid: _taskCenterController.loadingTaskDetailsUuid,
          taskDetailJobIdController:
              _taskCenterController.taskDetailJobIdController,
          taskProjects: _taskCenterController.taskProjects,
          taskCategoriesLine: _taskCenterController.taskCategoriesLine,
          taskApiSummaryLine: _taskCenterController.taskApiSummaryLine,
          taskDetailNumericIdLine:
              _taskCenterController.taskDetailNumericIdLine,
          taskDetailUuidLine: _taskCenterController.taskDetailUuidLine,
          taskApiJobs: _taskCenterController.taskApiJobs,
          taskApiLoadState: _taskCenterController.taskApiLoadState,
          taskApiLastError: _taskCenterController.taskApiLastError,
          onTaskDetailJobIdChanged: (_) =>
              _taskCenterController.notifyJobIdChanged(),
          onLoadTaskProjects: _taskCenterController.loadTaskProjects,
          onLoadTaskCategories: _taskCenterController.loadTaskCategories,
          onLoadTaskApi: _taskCenterController.loadTaskApi,
          onProbeTaskDetailByNumericId:
              _taskCenterController.probeTaskDetailByNumericId,
          onProbeTaskDetailUuid: _taskCenterController.probeTaskDetailUuid,
          onSelectTaskJob: _taskCenterController.selectTaskJob,
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.jobs)
        _buildFeatureGatedPane(
          enabled: _platformConfig.jobsPaneEnabled,
          title: l10n.productNavJobs,
          reason: l10n.productPaneDisabledJobs,
          child: JobsSection(
            controller: _jobsController,
            studioPresentation: widget.shellMode == HomeShellMode.product,
          ),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.quality)
        _buildFeatureGatedPane(
          enabled: _platformConfig.qualityDashboardEnabled,
          title: l10n.productNavQuality,
          reason: l10n.productPaneDisabledQuality,
          child: QualityReviewsSection(
            accessToken: _effectiveAccessToken,
            controller: _qualityReviewsController,
            initialProjectNumericId: _productScopedProjectNumericId,
            initialProjectUuid:
                _workspaceInputController.projectUuidController.text
                    .trim()
                    .isEmpty
                ? null
                : _workspaceInputController.projectUuidController.text.trim(),
            platformConfig: _platformConfig,
            studioPresentation: widget.shellMode == HomeShellMode.product,
            onNavigateDomainDeepLink: (TaskCenterDomainDeepLink link) {
              _applyDomainDeepLink(link);
            },
          ),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.platformConfig)
        _PlatformConfigSection(
          accessToken: _effectiveAccessToken,
          currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
          initialConfig: _platformConfig,
          debugResponse: _activeDemoCatalog?.platformConfigResponse,
          onConfigSaved: (config) {
            if (!mounted) {
              return;
            }
            setState(() {
              _applyPlatformConfig(config);
            });
          },
        ),
    ];
  }
}
