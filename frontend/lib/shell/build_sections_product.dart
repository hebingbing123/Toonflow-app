// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageBuildProductSections on _HomePageState {
  Future<void> _refreshRecentProjectIds() async {
    final ids = await StudioRecentProjectsPrefs.load();
    if (!mounted) {
      return;
    }
    setState(() => _recentProjectIds = ids);
    await _applyDefaultProductProjectScopeIfNeeded();
  }

  Future<void> _applyDefaultProductProjectScopeIfNeeded() async {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    if (_productScopedProjectNumericId != null) {
      return;
    }
    final projects = _projectsController.projects;
    if (projects == null || projects.isEmpty) {
      return;
    }

    var recentIds = _recentProjectIds;
    if (recentIds.isEmpty) {
      recentIds = await StudioRecentProjectsPrefs.load();
      if (!mounted) {
        return;
      }
      if (recentIds.isNotEmpty) {
        setState(() => _recentProjectIds = recentIds);
      }
    }

    final row = resolveDefaultProductScopedProject(
      projects: projects,
      recentProjectIds: recentIds,
    );
    if (row == null) {
      return;
    }
    await _selectProjectScope(row);
  }

  Future<void> _selectProjectScope(ProjectRow row) async {
    await StudioRecentProjectsPrefs.record(row.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _productScopedProjectNumericId = row.numericId;
      _recentProjectIds = <String>[
        row.id,
        ..._recentProjectIds.where((id) => id != row.id),
      ].take(3).toList(growable: false);
    });
    _workspaceInputController.applyProjectScope(
      row.numericId,
      projectUuid: row.id,
      workspaceId: row.workspaceId,
    );
  }

  void _applyDomainDeepLink(TaskCenterDomainDeepLink link) {
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
    if (link.target == TaskCenterDomainDeepLinkTarget.storyboard) {
      _workspaceInputController.applyProductionStoryboardFocus(
        scriptNumericId: link.scriptNumericId,
        storyboardNumericId: link.storyboardNumericId,
        suggestedAction: link.suggestedAction,
      );
    } else if (link.target == TaskCenterDomainDeepLinkTarget.script) {
      _workspaceInputController.applyScriptRepairFocus(
        scriptNumericId: link.scriptNumericId,
        stage: link.stage,
        suggestedAction: link.suggestedAction,
      );
    }
    if (widget.shellMode == HomeShellMode.product &&
        link.projectNumericId != null &&
        link.projectNumericId! > 0) {
      switch (link.target) {
        case TaskCenterDomainDeepLinkTarget.script:
          context.go(
            '/projects/${link.projectNumericId}/${StudioStep.script.slug}',
          );
          return;
        case TaskCenterDomainDeepLinkTarget.storyboard:
          context.go(
            '/projects/${link.projectNumericId}/${StudioStep.storyboard.slug}',
          );
          return;
        case TaskCenterDomainDeepLinkTarget.publish:
        case TaskCenterDomainDeepLinkTarget.project:
          break;
      }
    }
    switch (link.target) {
      case TaskCenterDomainDeepLinkTarget.publish:
      case TaskCenterDomainDeepLinkTarget.project:
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.shortVideoSpace,
        );
        break;
      case TaskCenterDomainDeepLinkTarget.script:
        if (widget.shellMode == HomeShellMode.product &&
            link.projectNumericId != null &&
            link.projectNumericId! > 0) {
          context.go(
            '/projects/${link.projectNumericId}/${StudioStep.script.slug}',
          );
        } else {
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.scriptWorkspace,
          );
        }
        break;
      case TaskCenterDomainDeepLinkTarget.storyboard:
        if (widget.shellMode == HomeShellMode.product &&
            link.projectNumericId != null &&
            link.projectNumericId! > 0) {
          context.go(
            '/projects/${link.projectNumericId}/${StudioStep.storyboard.slug}',
          );
        } else {
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.productionWorkspace,
          );
        }
        break;
    }
  }

  Future<void> _openProjectStudio(ProjectRow row) async {
    final token = _session?.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    await _selectProjectScope(row);
    if (!mounted) {
      return;
    }
    _shellNavigationController.selectProductWorkspacePane(
      ProductWorkspacePane.projects,
    );
    context.go('/projects/${row.numericId}/script');
  }

  ProjectRow? _studioProjectRow() {
    final id = widget.studioProjectNumericId ?? _productScopedProjectNumericId;
    if (id == null) return null;
    final list = _projectsController.projects;
    if (list == null) return null;
    for (final row in list) {
      if (row.numericId == id) return row;
    }
    return null;
  }

  Future<void> _runStudioAgent(String kind) async {
    if (!mounted) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.studioAgentSubmitted(kind))));
    switch (kind) {
      case 'script_rewriter':
      case 'extractor':
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.scriptWorkspace,
        );
        break;
      case 'storyboard_breaker':
      case 'grid_prompt_generator':
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.productionWorkspace,
        );
        break;
      case 'voice_assigner':
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.shortVideoSpace,
        );
        break;
    }
  }

  List<Widget> _buildStudioOverlayWidgets(BuildContext context) {
    final row = _studioProjectRow();
    final effectiveProjectUuid =
        widget.debugStudioProjectUuid ??
        row?.id ??
        _workspaceInputController.projectUuidController.text;
    final effectiveProjectName = widget.debugStudioProjectName ?? row?.name;
    final resolved = resolveStudioOverlay(
      overlayMode: widget.studioOverlay,
      widgetProjectNumericId: widget.studioProjectNumericId,
      productScopedProjectNumericId: _productScopedProjectNumericId,
      widgetScriptNumericId: widget.studioScriptNumericId,
      rowProjectUuid: widget.debugStudioProjectUuid ?? row?.id,
      workspaceProjectUuid: effectiveProjectUuid,
      accessToken: _effectiveAccessToken,
    );

    final token = _effectiveAccessToken ?? '';
    final l10n = resolveAppLocalizationsForErrors(context);

    return buildStudioOverlayChildren(
      resolved: resolved,
      loadingChild: const Center(child: CircularProgressIndicator()),
      storyboardBuilder: (projectNumericId) => StoryboardStudioPage(
        projectNumericId: projectNumericId,
        projectUuid: effectiveProjectUuid,
        accessToken: token,
        onOpenProductionWorkspace: () {
          _openShellPaneFromStudioOverlay(
            ProductWorkspacePane.productionWorkspace,
            projectNumericId: projectNumericId,
            projectUuid: effectiveProjectUuid,
          );
        },
        onOpenShotEditor:
            ({required int scriptNumericId, required int storyboardNumericId}) {
              return _openStoryboardEditor(
                token,
                storyboardNumericId,
                projectId: effectiveProjectUuid,
                scriptNumericId: scriptNumericId,
              );
            },
      ),
      episodeConsoleBuilder: (projectNumericId, scriptNumericId) =>
          EpisodeConsolePage(
            projectNumericId: projectNumericId,
            scriptNumericId: scriptNumericId,
            deliverChild: _buildShortVideoSpaceSection(),
            onOpenFullStudio: () => context.go(
              '/projects/$projectNumericId/${StudioStep.script.slug}',
            ),
          ),
      projectStudioBuilder: (projectNumericId, projectUuid) =>
          ProjectStudioScope(
            accessToken: token,
            projectNumericId: projectNumericId,
            projectUuid: projectUuid,
            projectName: effectiveProjectName,
            initialStep: StudioStep.fromSlug(widget.studioStepSlug),
            loadSnapshot: widget.debugProjectStudioSnapshotLoader,
            hostFactory: (readiness, refreshSnapshot) => ProjectStudioHost(
              projectNumericId: projectNumericId,
              projectUuid: projectUuid,
              projectName: effectiveProjectName,
              accessToken: token,
              home: readiness.home,
              assetsOverview: readiness.assetsOverview,
              onOpenTasks: () {
                _openShellPaneFromStudioOverlay(
                  ProductWorkspacePane.tasks,
                  projectNumericId: projectNumericId,
                  projectUuid: projectUuid,
                );
              },
              onOpenAssetEditor: (target) =>
                  _openProjectAssetsWorkbenchFromStudio(
                    ProjectRow(
                      id: projectUuid,
                      numericId: projectNumericId,
                      name: effectiveProjectName,
                      intro: null,
                      projectType: null,
                      imageModel: null,
                      imageQuality: null,
                      videoModel: null,
                      artStyle: null,
                      directorManual: null,
                      mode: null,
                      videoRatio: null,
                      createTimeMs: null,
                      artStylePack: null,
                      storyStylePack: null,
                      targetMarket: null,
                      targetPlatforms: null,
                      durationStrategy: null,
                      voiceProfile: null,
                      subtitleStyle: null,
                      bgmStrategy: null,
                      projectAccessMode: 'restricted',
                      projectAccessRole: 'editor',
                    ),
                    target,
                    onProjectSnapshotChanged: () async {
                      kStudioSnapshotBus.invalidate(
                        StudioSnapshotInvalidation.workbenchMedia,
                      );
                      await refreshSnapshot();
                    },
                  ),
              initialStep: StudioStep.fromSlug(widget.studioStepSlug),
              completedSteps: readiness.completedSteps,
              runningJobCount: readiness.runningJobCount,
              failedJobCount: readiness.failedJobCount,
              onExit: () => context.go('/'),
              onStepChanged: (_) {},
              onOpenAgentDrawer: () =>
                  showStudioAgentDrawer(context, onRunAgent: _runStudioAgent),
              onRunHarnessAgent: _runStudioAgent,
              buildStepBody: (step) => _buildProjectStudioStepBody(
                context,
                l10n,
                step,
                projectNumericId,
              ),
            ),
          ),
    );
  }

  void _openShellPaneFromStudioOverlay(
    ProductWorkspacePane pane, {
    int? projectNumericId,
    String? projectUuid,
    int? scriptNumericId,
    String? scriptUuid,
    String? workspaceId,
  }) {
    if (projectNumericId != null && projectNumericId > 0) {
      setState(() {
        _productScopedProjectNumericId = projectNumericId;
      });
      _workspaceInputController.applyProjectScope(
        projectNumericId,
        scriptNumericId: scriptNumericId,
        projectUuid: projectUuid,
        scriptUuid: scriptUuid,
        workspaceId: workspaceId,
      );
    }
    _shellNavigationController.selectProductWorkspacePane(pane);
    _ensureProductPaneData(pane);
    if (kStudioPaneUriSyncedPanes.contains(pane)) {
      context.go(studioUriForUtilityPane(pane));
    }
  }

  Widget _buildProjectStudioStepBody(
    BuildContext context,
    AppLocalizations l10n,
    StudioStep step,
    int projectNumericId,
  ) {
    switch (step) {
      case StudioStep.script:
        return _buildAgentWorkspacePane(
          initialPane: AgentWorkspacePane.script,
          sectionTitle: l10n.productAgentScriptWorkspaceTitle,
          sectionDescription: l10n.productAgentScriptWorkspaceSubtitle,
        );
      case StudioStep.art:
        return _buildAgentWorkspacePane(
          initialPane: AgentWorkspacePane.script,
          sectionTitle: l10n.studioStepArtTitle,
          sectionDescription: l10n.studioStepArtBody,
        );
      case StudioStep.assets:
      case StudioStep.storyboard:
        return _buildAgentWorkspacePane(
          initialPane: AgentWorkspacePane.production,
          sectionTitle: l10n.productAgentProductionWorkspaceTitle,
          sectionDescription: l10n.productAgentProductionWorkspaceSubtitle,
        );
      case StudioStep.video:
        return StudioVideoStepPanel(
          projectNumericId: projectNumericId,
          onOpenProduction: () {
            _openShellPaneFromStudioOverlay(
              ProductWorkspacePane.productionWorkspace,
              projectNumericId: projectNumericId,
            );
          },
          embeddedChild: _buildAgentWorkspacePane(
            initialPane: AgentWorkspacePane.production,
            sectionTitle: l10n.studioStepVideoTitle,
            sectionDescription: l10n.studioStepVideoBody,
          ),
        );
      case StudioStep.deliver:
        return DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TabBar(
                tabs: <Tab>[
                  Tab(text: l10n.studioDeliverTabAssembly),
                  Tab(text: l10n.studioDeliverTabPublish),
                  Tab(text: l10n.studioDeliverTabQuality),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        StudioMergeDeliverBar(
                          onMergeAndPreview: () {
                            setState(() {
                              _shortVideoSpaceInitialFocus =
                                  ShortVideoSpaceInitialFocus.assembly;
                            });
                            _openShellPaneFromStudioOverlay(
                              ProductWorkspacePane.shortVideoSpace,
                              projectNumericId: projectNumericId,
                            );
                          },
                        ),
                        Expanded(child: _buildShortVideoSpaceSection()),
                      ],
                    ),
                    Center(child: Text(l10n.studioDeliverPublishHint)),
                    Center(child: Text(l10n.studioDeliverQualityHint)),
                  ],
                ),
              ),
            ],
          ),
        );
      case StudioStep.quality:
        return Center(child: Text(l10n.studioDeliverQualityHint));
    }
  }

  Widget _buildShortVideoSpaceSection() {
    return ShortVideoSpaceSection(
      accessToken: _session?.accessToken,
      initialFocus: _shortVideoSpaceInitialFocus,
      initialProjectUuid:
          _workspaceInputController.projectUuidController.text.trim().isEmpty
          ? null
          : _workspaceInputController.projectUuidController.text.trim(),
      onOpenProjects: () => context.go('/'),
      onSyncProjectContext: (projectScope) {
        setState(() {
          _productScopedProjectNumericId = projectScope?.projectNumericId;
        });
        if (projectScope == null) {
          _workspaceInputController.projectIdController.clear();
          _workspaceInputController.projectUuidController.clear();
          _workspaceInputController.workspaceUuidController.clear();
          _workspaceInputController.clearScriptScope();
          return;
        }
        _workspaceInputController.applyProjectScope(
          projectScope.projectNumericId,
          projectUuid: projectScope.projectUuid,
          workspaceId: projectScope.workspaceId,
        );
        _workspaceInputController.clearScriptScope();
      },
      onOpenScriptWorkspace: () {
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.scriptWorkspace,
        );
      },
      onOpenProductionWorkspace: () {
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.productionWorkspace,
        );
      },
      onOpenTasks: () {
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.tasks,
        );
      },
      onOpenQuality: () {
        _selectProductPaneWithGate(
          ProductWorkspacePane.quality,
          disabledReason: resolveAppLocalizationsForErrors(
            context,
          ).productPaneDisabledQuality,
        );
      },
    );
  }

  Future<void> _openComplianceProductTarget(
    ContentComplianceReportItemV1 item,
  ) async {
    if (!mounted) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final messenger = ScaffoldMessenger.of(context);
    switch (item.targetType) {
      case 'user':
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.account,
        );
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.productComplianceSnackAccountPanel)),
        );
        return;
      default:
        break;
    }

    final token = _session?.accessToken;
    final projectId =
        item.projectId ?? (item.targetType == 'project' ? item.targetId : null);
    if (token == null || token.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.productComplianceSnackNotSignedIn)),
      );
      return;
    }
    if (projectId == null || projectId.isEmpty) {
      if ((item.workspaceId ?? '').isNotEmpty) {
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.teamWorkspaces,
        );
        final wsDetail = 'workspace ${item.workspaceName ?? item.workspaceId!}';
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.productComplianceTeamContext(wsDetail))),
        );
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.productComplianceNoProjectContext)),
      );
      return;
    }

    try {
      final detail = await fetchProjectByProjectId(token, projectId);
      if (!mounted) {
        return;
      }
      final row = detail.project;
      setState(() {
        _productScopedProjectNumericId = row.numericId;
      });
      _workspaceInputController.applyProjectScope(
        row.numericId,
        projectUuid: row.id,
        workspaceId: row.workspaceId,
      );
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.projects,
      );
      await _openProjectDetail(row);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.productComplianceOpenTargetFailed(
              describeUserVisibleApiError(l10n, error),
            ),
          ),
        ),
      );
    }
  }

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
          showBack: widget.shellMode == HomeShellMode.product,
          onBack: () {
            if (!_popProductWorkspacePane()) {
              _goToProjectsHome();
            }
          },
        ),
        const SizedBox(height: 32),
        Center(
          child: StudioEmptyState(
            title: l10n.studioProductHarnessRedirectTitle,
            subtitle: l10n.studioProductHarnessRedirectSubtitle,
            icon: icon,
            actionLabel: projectId != null ? l10n.studioEnterStudio : null,
            onAction: projectId != null
                ? () => context.go(
                    '/projects/$projectId/${enterStudioStep.slug}',
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAgentWorkspacePane({
    required AgentWorkspacePane initialPane,
    required String sectionTitle,
    required String sectionDescription,
  }) {
    return AgentWorkspacesSection(
      initialPane: initialPane,
      showPaneSelector: false,
      sectionTitle: sectionTitle,
      sectionDescription: sectionDescription,
      projectIdController: _workspaceInputController.projectIdController,
      scriptIdController: _workspaceInputController.scriptIdController,
      projectUuidController: _workspaceInputController.projectUuidController,
      scriptUuidController: _workspaceInputController.scriptUuidController,
      workspaceUuidController:
          _workspaceInputController.workspaceUuidController,
      scriptPromptController: _workspaceInputController.scriptPromptController,
      scriptDomainFocusRevision:
          _workspaceInputController.scriptDomainFocusRevision,
      scriptDomainToolController:
          _workspaceInputController.scriptDomainToolController,
      scriptDomainArgsController:
          _workspaceInputController.scriptDomainArgsController,
      productionPromptController:
          _workspaceInputController.productionPromptController,
      productionDomainFocusRevision:
          _workspaceInputController.productionDomainFocusRevision,
      flowKeyController: _workspaceInputController.productionFlowKeyController,
      productionDomainToolController:
          _workspaceInputController.productionDomainToolController,
      productionDomainArgsController:
          _workspaceInputController.productionDomainArgsController,
      productionSubAgentArgsController:
          _workspaceInputController.productionSubAgentArgsController,
      loadingScriptWorkspaceRun:
          _workspaceOperationController.loadingScriptWorkspaceRun,
      loadingProductionWorkspaceRun:
          _workspaceOperationController.loadingProductionWorkspaceRun,
      loadingScriptDomainProbe:
          _workspaceOperationController.loadingScriptDomainProbe,
      loadingProductionFlowProbe:
          _workspaceOperationController.loadingProductionFlowProbe,
      loadingScriptSubAgentRun:
          _workspaceOperationController.loadingScriptSubAgentRun,
      loadingProductionSubAgentRun:
          _workspaceOperationController.loadingProductionSubAgentRun,
      loadingScriptResultWriteback:
          _workspaceOperationController.loadingScriptResultWriteback,
      loadingScriptPlanResultWriteback:
          _workspaceOperationController.loadingScriptPlanResultWriteback,
      loadingProductionResultWriteback:
          _workspaceOperationController.loadingProductionResultWriteback,
      wsLog: _wsLog,
      workspaceAssistantText: _workspaceOutputController.assistantText,
      workspaceScriptWritebackCandidate:
          _workspaceOutputController.scriptWritebackCandidate,
      workspaceScriptPlanWritebackCandidate:
          _workspaceOutputController.scriptPlanWritebackCandidate,
      workspaceScriptPlanRowId: _workspaceOutputController.scriptPlanRowId,
      workspaceScriptWritebackSource:
          _workspaceOutputController.scriptWritebackSource,
      workspaceLastToolResultLine:
          _workspaceOutputController.lastToolResultLine,
      workspaceLastToolName: _workspaceOutputController.lastToolName,
      workspaceLastToolResultData:
          _workspaceOutputController.lastToolResultData,
      workspaceLastToolArguments: _workspaceOutputController.lastToolArguments,
      workspaceSuggestedFlowKey: _workspaceOutputController.suggestedFlowKey,
      workspaceWritebackLine: _workspaceOutputController.writebackLine,
      onRunScriptWorkspace: _workspaceRunController.runScriptWorkspaceAgent,
      onRunProductionWorkspace:
          _workspaceRunController.runProductionWorkspaceAgent,
      onProbeScriptDomainTool: _workspaceRunController.probeScriptDomainTool,
      onProbeProductionDomainTool:
          _workspaceRunController.probeProductionDomainTool,
      scriptSubAgentToolController:
          _workspaceInputController.scriptSubAgentToolController,
      productionSubAgentToolController:
          _workspaceInputController.productionSubAgentToolController,
      onRunScriptSubAgentTool: _workspaceRunController.runScriptSubAgentTool,
      onRunProductionSubAgentTool:
          _workspaceRunController.runProductionSubAgentTool,
      onWriteBackScriptResult:
          _workspaceWritebackController.writeBackScriptWorkspaceResult,
      onWriteBackScriptPlanResult:
          _workspaceWritebackController.writeBackScriptPlanWorkspaceResult,
      onWriteBackScriptPlanViaUpdateData:
          _workspaceWritebackController.writeBackScriptPlanViaUpdateData,
      onWriteBackProductionFlowResult:
          _workspaceWritebackController.writeBackProductionFlowResult,
      onApplySuggestedFlowKey: () {
        _workspaceInputController.applySuggestedProductionFlowKey(
          _workspaceOutputController.suggestedFlowKey,
        );
      },
    );
  }

  List<Widget> _buildProductSections(BuildContext context) {
    return <Widget>[
      _buildProductPaneSelector(context),
      ..._buildActiveProductPaneWidgets(context),
    ];
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
            accessToken: _session?.accessToken,
            debugWebhooks: widget.debugHelpHubWebhooks,
            debugLatestCreatedWebhook: widget.debugHelpHubLatestCreatedWebhook,
            debugBillingEventsPage: widget.debugHelpHubBillingEventsPage,
            debugWebhookDeliveries: widget.debugHelpHubWebhookDeliveries,
            debugWebhookLastTestResults:
                widget.debugHelpHubWebhookLastTestResults,
          ),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.shortVideoSpace)
        _buildShortVideoSpaceSection(),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.projects)
        ProjectsSection(
          accessToken: _session?.accessToken,
          controller: _projectsController,
          productPresentation: widget.shellMode == HomeShellMode.product,
          currentWorkspaceName: _sessionMe?.currentWorkspace?.name,
          currentWorkspaceType: _sessionMe?.currentWorkspace?.workspaceType,
          currentProjectNumericId: _productScopedProjectNumericId,
          onOpenProjectDetail: _openProjectDetail,
          onSelectProjectScope: _selectProjectScope,
          onOpenProjectStudio: _openProjectStudio,
          onOpenTeamWorkspaces: () {
            _shellNavigationController.selectProductWorkspacePane(
              ProductWorkspacePane.teamWorkspaces,
            );
          },
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.account)
        widget.shellMode == HomeShellMode.product
            ? SettingsHubPage(
                accountController: _accountController,
                apiKeysController: _apiKeysController,
                accessToken: _session?.accessToken,
                onAccountDeleted: _handleAccountDeleted,
                onWorkspaceContextChanged: _handleWorkspaceContextChanged,
                currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
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
          accessToken: _session?.accessToken,
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
          child: BenchmarkSection(accessToken: _session?.accessToken),
        ),
      if (_shellNavigationController.productWorkspacePane ==
          ProductWorkspacePane.tasks)
        TaskCenterSection(
          studioPresentation: widget.shellMode == HomeShellMode.product,
          accessToken: _session?.accessToken,
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
            accessToken: _session?.accessToken,
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
          accessToken: _session?.accessToken,
          currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
          initialConfig: _platformConfig,
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

class _ProductPaneSelector extends StatefulWidget {
  const _ProductPaneSelector({
    required this.config,
    required this.unreadNotifications,
    required this.selectedPane,
    required this.onSelectPane,
  });

  final PlatformConfigToggleSetV1 config;
  final int unreadNotifications;
  final ProductWorkspacePane selectedPane;
  final ValueChanged<ProductWorkspacePane> onSelectPane;

  @override
  State<_ProductPaneSelector> createState() => _ProductPaneSelectorState();
}

class _ProductPaneSelectorState extends State<_ProductPaneSelector> {
  bool _isPaneEnabled(ProductWorkspacePane pane) {
    switch (pane) {
      case ProductWorkspacePane.helpHub:
        return widget.config.helpHubEnabled;
      case ProductWorkspacePane.platformStatus:
        return widget.config.platformStatusEnabled;
      case ProductWorkspacePane.workspaceActivity:
        return widget.config.workspaceActivityEnabled;
      case ProductWorkspacePane.benchmark:
        return widget.config.benchmarkPaneEnabled;
      case ProductWorkspacePane.jobs:
        return widget.config.jobsPaneEnabled;
      case ProductWorkspacePane.quality:
        return widget.config.qualityDashboardEnabled;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final paneEntries = <(ProductWorkspacePane, String, int?)>[
      (
        ProductWorkspacePane.shortVideoSpace,
        l10n.productNavShortVideoSpace,
        null,
      ),
      (ProductWorkspacePane.projects, l10n.productNavProjects, null),
      (ProductWorkspacePane.account, l10n.productNavAccount, null),
      (ProductWorkspacePane.apiKeys, l10n.productNavApiKeys, null),
      (
        ProductWorkspacePane.notifications,
        l10n.productNavNotifications,
        widget.unreadNotifications,
      ),
      (
        ProductWorkspacePane.contentCompliance,
        l10n.productNavContentCompliance,
        null,
      ),
      (
        ProductWorkspacePane.platformStatus,
        l10n.productNavPlatformStatus,
        null,
      ),
      (
        ProductWorkspacePane.teamWorkspaces,
        l10n.productNavTeamWorkspaces,
        null,
      ),
      (
        ProductWorkspacePane.scriptWorkspace,
        l10n.productNavScriptWorkspace,
        null,
      ),
      (
        ProductWorkspacePane.productionWorkspace,
        l10n.productNavProductionWorkspace,
        null,
      ),
      (
        ProductWorkspacePane.workspaceActivity,
        l10n.productNavWorkspaceActivity,
        null,
      ),
      (ProductWorkspacePane.benchmark, l10n.productNavBenchmark, null),
      (ProductWorkspacePane.tasks, l10n.productNavTasks, null),
      (ProductWorkspacePane.jobs, l10n.productNavJobs, null),
      (ProductWorkspacePane.quality, l10n.productNavQuality, null),
      (
        ProductWorkspacePane.platformConfig,
        l10n.productNavPlatformConfig,
        null,
      ),
      (ProductWorkspacePane.helpHub, l10n.productNavHelp, null),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.productNavSectionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: paneEntries
                .map((entry) {
                  final pane = entry.$1;
                  final enabled = _isPaneEnabled(pane);
                  final unread = entry.$3;
                  return ChoiceChip(
                    label: Text(
                      unread != null && unread > 0
                          ? '${entry.$2} ($unread)'
                          : entry.$2,
                    ),
                    selected: widget.selectedPane == pane,
                    onSelected: enabled
                        ? (selected) {
                            if (!selected) {
                              return;
                            }
                            widget.onSelectPane(pane);
                          }
                        : null,
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          PlatformShortDramaPipelineStrip(
            onSelectPane: widget.onSelectPane,
            jobsPaneEnabled: widget.config.jobsPaneEnabled,
            qualityPaneEnabled: widget.config.qualityDashboardEnabled,
          ),
        ],
      ),
    );
  }
}

class _PlatformPaneDisabledNotice extends StatelessWidget {
  const _PlatformPaneDisabledNotice({
    required this.title,
    required this.reason,
  });

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: outline.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(reason, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _PlatformConfigSection extends StatefulWidget {
  const _PlatformConfigSection({
    required this.accessToken,
    required this.currentWorkspaceId,
    required this.initialConfig,
    required this.onConfigSaved,
  });

  final String? accessToken;
  final String? currentWorkspaceId;
  final PlatformConfigToggleSetV1 initialConfig;
  final ValueChanged<PlatformConfigToggleSetV1> onConfigSaved;

  @override
  State<_PlatformConfigSection> createState() => _PlatformConfigSectionState();
}

class _PlatformConfigSectionState extends State<_PlatformConfigSection> {
  bool _loading = false;
  bool _savingUser = false;
  bool _savingWorkspace = false;
  String? _error;
  int _loadRequestEpoch = 0;
  PlatformConfigResponseV1? _response;
  PlatformConfigToggleSetV1? _userDraft;
  PlatformConfigToggleSetV1? _workspaceDraft;

  @override
  void initState() {
    super.initState();
    _userDraft = widget.initialConfig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant _PlatformConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contextChanged =
        oldWidget.accessToken != widget.accessToken ||
        oldWidget.currentWorkspaceId != widget.currentWorkspaceId;
    if (oldWidget.initialConfig != widget.initialConfig &&
        !_savingUser &&
        !_savingWorkspace &&
        _response == null) {
      _userDraft = widget.initialConfig;
    }
    if (contextChanged) {
      _response = null;
      _error = null;
      _savingUser = false;
      _savingWorkspace = false;
      _userDraft = widget.initialConfig;
      _workspaceDraft = null;
      unawaited(_load());
    }
  }

  bool _isCurrentLoadRequest(
    int requestEpoch,
    String token,
    String? workspaceId,
  ) {
    return mounted &&
        requestEpoch == _loadRequestEpoch &&
        widget.accessToken == token &&
        widget.currentWorkspaceId == workspaceId;
  }

  bool _isCurrentMutationContext(String token, String? workspaceId) {
    return mounted &&
        widget.accessToken == token &&
        widget.currentWorkspaceId == workspaceId;
  }

  PlatformConfigToggleSetV1? _workspaceDraftForResponse(
    PlatformConfigResponseV1 response,
  ) {
    return response.workspaceOverride ??
        (response.currentWorkspace?.canManageOverride == true
            ? PlatformConfigToggleSetV1.defaults
            : null);
  }

  void _applyResponse(PlatformConfigResponseV1 response) {
    _response = response;
    _userDraft = response.userOverride;
    _workspaceDraft = _workspaceDraftForResponse(response);
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    if (token == null || token.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _error = l10n.platformConfigPleaseSignIn;
        _response = null;
        _userDraft = null;
        _workspaceDraft = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final requestEpoch = ++_loadRequestEpoch;
    try {
      final res = await fetchPlatformConfigV1(token);
      if (!_isCurrentLoadRequest(requestEpoch, token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
    } catch (e) {
      if (!_isCurrentLoadRequest(requestEpoch, token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (_isCurrentLoadRequest(requestEpoch, token, workspaceId)) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveUser() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    final draft = _userDraft;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null || token.isEmpty || draft == null) {
      return;
    }
    setState(() {
      _savingUser = true;
      _error = null;
    });
    try {
      final res = await postPlatformConfigV1(token, draft, scope: 'user');
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(
              context,
            ).platformConfigSnackUserSaved,
          ),
        ),
      );
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingUser = false;
        });
      }
    }
  }

  Future<void> _resetUser() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _savingUser = true;
      _error = null;
    });
    try {
      final res = await postPlatformConfigV1(
        token,
        null,
        scope: 'user',
        reset: true,
      );
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(
              context,
            ).platformConfigSnackUserReset,
          ),
        ),
      );
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingUser = false;
        });
      }
    }
  }

  Future<void> _saveWorkspace() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    final draft = _workspaceDraft;
    final workspace = _response?.currentWorkspace;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null ||
        token.isEmpty ||
        draft == null ||
        workspace == null ||
        !workspace.canManageOverride) {
      return;
    }
    setState(() {
      _savingWorkspace = true;
      _error = null;
    });
    try {
      final res = await postPlatformConfigV1(token, draft, scope: 'workspace');
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(
              context,
            ).platformConfigSnackWorkspaceSaved,
          ),
        ),
      );
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingWorkspace = false;
        });
      }
    }
  }

  Future<void> _resetWorkspace() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    final workspace = _response?.currentWorkspace;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null ||
        token.isEmpty ||
        workspace == null ||
        !workspace.canManageOverride) {
      return;
    }
    setState(() {
      _savingWorkspace = true;
      _error = null;
    });
    try {
      final res = await postPlatformConfigV1(
        token,
        null,
        scope: 'workspace',
        reset: true,
      );
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(
              context,
            ).platformConfigSnackWorkspaceReset,
          ),
        ),
      );
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingWorkspace = false;
        });
      }
    }
  }

  Future<void> _copyConfig() async {
    final response = _response;
    if (response == null) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'scope': response.scope,
          'schemaVersion': response.schemaVersion,
          'effective': response.effective.toJson(),
          'planTier': response.planTier,
          'planOverride': response.planOverride?.toJson(),
          'hasPlanOverride': response.hasPlanOverride,
          'userOverride': response.userOverride.toJson(),
          'hasUserOverride': response.hasUserOverride,
          'workspaceOverride': response.workspaceOverride?.toJson(),
          'hasWorkspaceOverride': response.hasWorkspaceOverride,
          'currentWorkspace': response.currentWorkspace == null
              ? null
              : <String, dynamic>{
                  'id': response.currentWorkspace!.id,
                  'name': response.currentWorkspace!.name,
                  'workspaceType': response.currentWorkspace!.workspaceType,
                  'role': response.currentWorkspace!.role,
                  'canManageOverride':
                      response.currentWorkspace!.canManageOverride,
                },
        }),
      ),
    );
    if (!mounted) {
      return;
    }
    final loc = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.platformConfigSnackCopyJsonDone)),
    );
  }

  void _patchUserDraft(PlatformConfigToggleSetV1 next) {
    setState(() {
      _userDraft = next;
    });
  }

  void _patchWorkspaceDraft(PlatformConfigToggleSetV1 next) {
    setState(() {
      _workspaceDraft = next;
    });
  }

  Widget _buildToggleEditor({
    required AppLocalizations l10n,
    required PlatformConfigToggleSetV1 draft,
    required ValueChanged<PlatformConfigToggleSetV1>? onChanged,
  }) {
    return Column(
      children: [
        SwitchListTile(
          value: draft.helpHubEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(helpHubEnabled: v)),
          title: Text(l10n.platformConfigToggleHelpHubTitle),
          subtitle: Text(l10n.platformConfigToggleHelpHubSubtitle),
        ),
        SwitchListTile(
          value: draft.qualityDashboardEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(qualityDashboardEnabled: v)),
          title: Text(l10n.platformConfigToggleQualityMainTitle),
          subtitle: Text(l10n.platformConfigToggleQualityMainSubtitle),
        ),
        SwitchListTile(
          value: draft.qualityRefreshControlsEnabled,
          onChanged: onChanged == null
              ? null
              : (v) =>
                    onChanged(draft.copyWith(qualityRefreshControlsEnabled: v)),
          title: Text(l10n.platformConfigToggleQualityRefreshTitle),
          subtitle: Text(l10n.platformConfigToggleQualityRefreshSubtitle),
        ),
        SwitchListTile(
          value: draft.platformStatusEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(platformStatusEnabled: v)),
          title: Text(l10n.platformConfigTogglePlatformStatusTitle),
          subtitle: Text(l10n.platformConfigTogglePlatformStatusSubtitle),
        ),
        SwitchListTile(
          value: draft.workspaceActivityEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(workspaceActivityEnabled: v)),
          title: Text(l10n.platformConfigToggleWorkspaceActivityTitle),
          subtitle: Text(l10n.platformConfigToggleWorkspaceActivitySubtitle),
        ),
        SwitchListTile(
          value: draft.benchmarkPaneEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(benchmarkPaneEnabled: v)),
          title: Text(l10n.platformConfigToggleBenchmarkTitle),
          subtitle: Text(l10n.platformConfigToggleBenchmarkSubtitle),
        ),
        SwitchListTile(
          value: draft.jobsPaneEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(jobsPaneEnabled: v)),
          title: Text(l10n.platformConfigToggleJobsTitle),
          subtitle: Text(l10n.platformConfigToggleJobsSubtitle),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final userDraft = _userDraft;
    final workspaceDraft = _workspaceDraft;
    final workspace = _response?.currentWorkspace;
    final userDraftDirty =
        userDraft != null &&
        _response != null &&
        userDraft != _response!.userOverride;
    final workspaceBaseline =
        _response?.workspaceOverride ??
        ((_response?.currentWorkspace?.canManageOverride ?? false)
            ? PlatformConfigToggleSetV1.defaults
            : null);
    final workspaceDraftDirty =
        workspaceDraft != null &&
        workspaceBaseline != null &&
        workspaceDraft != workspaceBaseline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.platformConfigSectionTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.riskyPrefsTooltipSameAsMainPanelHeaders,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.platformConfigSectionSubtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.riskyPrefsMenuDefaultTooltip,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.platformConfigLocalPrefsDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _loading ? null : _load,
              child: Text(
                _loading
                    ? l10n.platformConfigButtonRefreshing
                    : l10n.platformConfigButtonRefresh,
              ),
            ),
            FilledButton(
              onPressed: _savingUser || !userDraftDirty ? null : _saveUser,
              child: Text(
                _savingUser
                    ? l10n.platformConfigButtonSaving
                    : l10n.platformConfigButtonSaveUser,
              ),
            ),
            OutlinedButton(
              onPressed: _savingUser || !(_response?.hasUserOverride ?? false)
                  ? null
                  : _resetUser,
              child: Text(l10n.platformConfigButtonResetUser),
            ),
            FilledButton.tonal(
              onPressed:
                  _savingWorkspace ||
                      !workspaceDraftDirty ||
                      workspace == null ||
                      !workspace.canManageOverride
                  ? null
                  : _saveWorkspace,
              child: Text(
                _savingWorkspace
                    ? l10n.platformConfigButtonSaving
                    : l10n.platformConfigButtonSaveWorkspace,
              ),
            ),
            OutlinedButton(
              onPressed:
                  _savingWorkspace ||
                      workspace == null ||
                      !workspace.canManageOverride ||
                      !(_response?.hasWorkspaceOverride ?? false)
                  ? null
                  : _resetWorkspace,
              child: Text(l10n.platformConfigButtonResetWorkspace),
            ),
            OutlinedButton(
              onPressed: _response == null ? null : _copyConfig,
              child: Text(l10n.platformConfigButtonCopyJson),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_response != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'scope=${_response!.scope} · schema=v${_response!.schemaVersion}',
          ),
          const SizedBox(height: 4),
          SelectableText(
            'plan_tier=${_response!.planTier} · has_plan_override=${_response!.hasPlanOverride}',
          ),
          if (workspace != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              'current_workspace=${workspace.name} (${workspace.workspaceType}) · role=${workspace.role} · can_manage_override=${workspace.canManageOverride}',
            ),
          ],
        ],
        if (_response != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.platformConfigPlanOverrideTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.platformConfigPlanLayerIntro,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'env: OPENFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            _response!.hasPlanOverride
                ? l10n.platformConfigPlanStateActive
                : l10n.platformConfigPlanStateInactive,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_response!.planOverride != null) ...[
            const SizedBox(height: 12),
            _buildToggleEditor(
              l10n: l10n,
              draft: _response!.planOverride!,
              onChanged: null,
            ),
          ],
        ],
        if (workspace != null && workspaceDraft != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.platformConfigWorkspaceOverrideTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            workspace.canManageOverride
                ? l10n.platformConfigWorkspaceEnterpriseIntro
                : l10n.platformConfigWorkspaceViewOnlyIntro,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            (_response?.hasWorkspaceOverride ?? false)
                ? l10n.platformConfigWorkspaceStateWritten
                : l10n.platformConfigWorkspaceStateInherit,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildToggleEditor(
            l10n: l10n,
            draft: workspaceDraft,
            onChanged: workspace.canManageOverride
                ? _patchWorkspaceDraft
                : null,
          ),
        ],
        if (workspace != null && workspaceDraft == null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.platformConfigWorkspaceOverrideTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            workspace.workspaceType == 'enterprise'
                ? l10n.platformConfigWorkspaceNoDraftEnterprise
                : l10n.platformConfigWorkspaceNoDraftPersonal,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (userDraft != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.platformConfigUserOverrideTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.platformConfigUserOverrideIntro,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            (_response?.hasUserOverride ?? false)
                ? l10n.platformConfigUserStateWritten
                : l10n.platformConfigUserStateInherit,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildToggleEditor(
            l10n: l10n,
            draft: userDraft,
            onChanged: _patchUserDraft,
          ),
        ],
      ],
    );
  }
}

class _HelpHubSection extends StatefulWidget {
  const _HelpHubSection({
    required this.accessToken,
    this.debugWebhooks,
    this.debugLatestCreatedWebhook,
    this.debugBillingEventsPage,
    this.debugWebhookDeliveries,
    this.debugWebhookLastTestResults,
  });

  final String? accessToken;
  final OutboundWebhookListResponseV1? debugWebhooks;
  final OutboundWebhookCreatedResponseV1? debugLatestCreatedWebhook;
  final BillingWebhookEventsResponseV1? debugBillingEventsPage;
  final Map<String, OutboundWebhookDeliveryListResponseV1>?
  debugWebhookDeliveries;
  final Map<String, OutboundWebhookTestResponseV1>? debugWebhookLastTestResults;

  @override
  State<_HelpHubSection> createState() => _HelpHubSectionState();
}

class _WebhookActivityEntry {
  const _WebhookActivityEntry({
    required this.at,
    required this.action,
    required this.webhookId,
    required this.summary,
  });

  final DateTime at;
  final String action;
  final String webhookId;
  final String summary;
}

class _HelpHubSectionState extends State<_HelpHubSection> {
  bool _loading = false;
  String? _error;
  HelpHubLinksResponseV1? _resp;
  HelpHubConfigResponseV1? _helpHubConfig;
  bool _savingHelpHubLinks = false;
  bool _loadingWebhooks = false;
  String? _webhooksError;
  OutboundWebhookListResponseV1? _webhooks;
  OutboundWebhookCreatedResponseV1? _latestCreatedWebhook;
  final _webhookUrlController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  final _webhookSearchController = TextEditingController();
  final _webhookTestEventTypeController = TextEditingController(
    text: 'test.ping',
  );
  final _webhookWorkspaceIdController = TextEditingController();

  /// Create form: selected platform event slugs (empty on server = all types).
  final Set<String> _createWebhookEventTypes = <String>{
    ...kOutboundWebhookPlatformEventTypes,
  };
  final _helpHubSearchController = TextEditingController();
  final _helpHubNewIdController = TextEditingController();
  final _helpHubNewTitleController = TextEditingController();
  final _helpHubNewUrlController = TextEditingController();
  String? _webhookBusyId;
  final Map<String, OutboundWebhookTestResponseV1> _webhookLastTestResultById =
      <String, OutboundWebhookTestResponseV1>{};
  final Map<String, OutboundWebhookDeliveryListResponseV1> _webhookDeliveries =
      <String, OutboundWebhookDeliveryListResponseV1>{};
  String? _loadingDeliveriesId;
  final List<_WebhookActivityEntry> _webhookActivity =
      <_WebhookActivityEntry>[];

  /// Per-row draft for PATCH `workspaceId` on existing webhooks.
  final Map<String, TextEditingController> _webhookWorkspaceDraftControllers =
      <String, TextEditingController>{};
  bool _loadingBillingEvents = false;
  bool _loadingMoreBillingEvents = false;
  bool _exportingAllBillingEvents = false;
  String? _billingEventsError;
  BillingWebhookEventsResponseV1? _billingEventsPage;
  final List<BillingWebhookEventItemV1> _billingEvents =
      <BillingWebhookEventItemV1>[];
  final _billingEventTypeController = TextEditingController();
  final _billingProviderEventIdController = TextEditingController();
  final _billingProviderEventIdPrefixController = TextEditingController();
  final _billingRawEventIdController = TextEditingController();
  final _billingRawEventIdPrefixController = TextEditingController();
  final _billingEventCreatedFromController = TextEditingController();
  final _billingEventCreatedToController = TextEditingController();
  final _billingCreatedFromController = TextEditingController();
  final _billingCreatedToController = TextEditingController();
  String _billingProvider = '';
  bool? _billingInformationalOnly;
  String _billingSort = 'id_desc';

  Future<void> _load() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = kProductShellSignInErrorPlaceholder;
        _resp = null;
        _helpHubConfig = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await getSettingsHelpHubConfigV1(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _helpHubConfig = cfg;
        _resp = HelpHubLinksResponseV1(items: cfg.effectiveItems);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
        _resp = null;
        _helpHubConfig = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (widget.debugWebhooks != null) {
      _webhooks = widget.debugWebhooks;
      _latestCreatedWebhook = widget.debugLatestCreatedWebhook;
      _webhookDeliveries.addAll(widget.debugWebhookDeliveries ?? const {});
      _webhookLastTestResultById.addAll(
        widget.debugWebhookLastTestResults ?? const {},
      );
      _syncWebhookWorkspaceDraftControllers();
    } else {
      unawaited(_loadWebhooks());
    }
    if (widget.debugBillingEventsPage != null) {
      _billingEventsPage = widget.debugBillingEventsPage;
      _billingEvents.addAll(widget.debugBillingEventsPage!.items);
    } else {
      unawaited(_loadBillingEvents());
    }
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
    _webhookSecretController.dispose();
    _webhookSearchController.dispose();
    _webhookTestEventTypeController.dispose();
    _webhookWorkspaceIdController.dispose();
    _helpHubSearchController.dispose();
    _helpHubNewIdController.dispose();
    _helpHubNewTitleController.dispose();
    _helpHubNewUrlController.dispose();
    _billingEventTypeController.dispose();
    _billingProviderEventIdController.dispose();
    _billingProviderEventIdPrefixController.dispose();
    _billingRawEventIdController.dispose();
    _billingRawEventIdPrefixController.dispose();
    _billingEventCreatedFromController.dispose();
    _billingEventCreatedToController.dispose();
    _billingCreatedFromController.dispose();
    _billingCreatedToController.dispose();
    for (final c in _webhookWorkspaceDraftControllers.values) {
      c.dispose();
    }
    _webhookWorkspaceDraftControllers.clear();
    super.dispose();
  }

  Future<void> _openHelpHubManageDialog() async {
    final token = widget.accessToken;
    final cfg = _helpHubConfig;
    if (token == null || token.isEmpty) {
      return;
    }
    if (cfg == null) {
      await _load();
      if (!mounted) {
        return;
      }
    }

    final initial = _helpHubConfig;
    if (initial == null) {
      return;
    }

    var userItems = initial.userItems.toList(growable: true);
    var workspaceItems = initial.workspaceItems.toList(growable: true);
    var useWorkspaceTab = initial.canManageWorkspace;
    var errorText = '';

    _helpHubNewIdController.text = '';
    _helpHubNewTitleController.text = '';
    _helpHubNewUrlController.text = '';

    Future<void> saveScope({required bool workspace}) async {
      setState(() {
        _savingHelpHubLinks = true;
      });
      try {
        final resp = workspace
            ? await postSettingsHelpHubWorkspaceLinksV1(
                token,
                items: workspaceItems,
              )
            : await postSettingsHelpHubUserLinksV1(token, items: userItems);
        if (!mounted) {
          return;
        }
        setState(() {
          _helpHubConfig = resp;
          _resp = HelpHubLinksResponseV1(items: resp.effectiveItems);
        });
      } catch (e) {
        errorText = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      } finally {
        if (mounted) {
          setState(() {
            _savingHelpHubLinks = false;
          });
        }
      }
    }

    await showStudioDialog<void>(
      context: context,
      builder: (ctx) {
        final dl10n = resolveAppLocalizationsForErrors(ctx);
        return StatefulBuilder(
          builder: (ctx, setInner) {
            final canManageWorkspace =
                _helpHubConfig?.canManageWorkspace ?? false;
            final activeIsWorkspace = canManageWorkspace && useWorkspaceTab;
            final activeItems = activeIsWorkspace ? workspaceItems : userItems;

            void addNew() {
              final id = _helpHubNewIdController.text.trim();
              final title = _helpHubNewTitleController.text.trim();
              final url = _helpHubNewUrlController.text.trim();
              if (id.isEmpty || title.isEmpty || url.isEmpty) {
                setInner(() {
                  errorText = dl10n.helpHubValidationRequired;
                });
                return;
              }
              setInner(() {
                errorText = '';
                activeItems.add(
                  HelpHubLinkItemV1(id: id, title: title, url: url),
                );
                _helpHubNewIdController.text = '';
                _helpHubNewTitleController.text = '';
                _helpHubNewUrlController.text = '';
              });
            }

            return StudioAlertDialog(
              title: Text(dl10n.helpHubManageDialogTitle),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dl10n.helpHubManagePrecedence +
                            (canManageWorkspace
                                ? ''
                                : dl10n.helpHubManageWorkspaceLocked),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (canManageWorkspace)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: Text(dl10n.helpHubTabPersonal),
                              selected: !activeIsWorkspace,
                              onSelected: (v) => setInner(() {
                                useWorkspaceTab = !v;
                                errorText = '';
                              }),
                            ),
                            FilterChip(
                              label: Text(dl10n.helpHubTabWorkspace),
                              selected: activeIsWorkspace,
                              onSelected: (v) => setInner(() {
                                useWorkspaceTab = v;
                                errorText = '';
                              }),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _helpHubNewIdController,
                        decoration: InputDecoration(
                          labelText: dl10n.helpHubFieldId,
                          hintText: dl10n.helpHubHintId,
                        ),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _helpHubNewTitleController,
                        decoration: InputDecoration(
                          labelText: dl10n.helpHubFieldTitle,
                        ),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _helpHubNewUrlController,
                        decoration: InputDecoration(
                          labelText: dl10n.helpHubFieldUrl,
                          hintText: dl10n.helpHubHintUrl,
                        ),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: _savingHelpHubLinks ? null : addNew,
                            child: Text(dl10n.helpHubAdd),
                          ),
                          if (errorText.isNotEmpty)
                            Text(
                              errorText,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (activeItems.isEmpty)
                        Text(
                          dl10n.helpHubNoCustomInScope,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ...activeItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.title} (${item.id})',
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      SelectableText(item.url),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: dl10n
                                      .notificationsComplianceTooltipMoveUp,
                                  onPressed: (_savingHelpHubLinks || idx == 0)
                                      ? null
                                      : () => setInner(() {
                                          final tmp = activeItems[idx - 1];
                                          activeItems[idx - 1] =
                                              activeItems[idx];
                                          activeItems[idx] = tmp;
                                        }),
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                IconButton(
                                  tooltip: dl10n
                                      .notificationsComplianceTooltipMoveDown,
                                  onPressed:
                                      (_savingHelpHubLinks ||
                                          idx >= activeItems.length - 1)
                                      ? null
                                      : () => setInner(() {
                                          final tmp = activeItems[idx + 1];
                                          activeItems[idx + 1] =
                                              activeItems[idx];
                                          activeItems[idx] = tmp;
                                        }),
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                                IconButton(
                                  tooltip: dl10n.notificationsActionDelete,
                                  onPressed: _savingHelpHubLinks
                                      ? null
                                      : () => setInner(() {
                                          activeItems.removeAt(idx);
                                        }),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _savingHelpHubLinks
                      ? null
                      : () => Navigator.pop(ctx),
                  child: Text(dl10n.helpHubDialogClose),
                ),
                FilledButton(
                  onPressed: _savingHelpHubLinks
                      ? null
                      : () async {
                          await saveScope(workspace: activeIsWorkspace);
                          if (!ctx.mounted) {
                            return;
                          }
                          if (errorText.isNotEmpty) {
                            setInner(() {});
                            return;
                          }
                          Navigator.pop(ctx);
                        },
                  child: Text(
                    _savingHelpHubLinks
                        ? dl10n.helpHubSaving
                        : dl10n.helpHubSave,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _syncWebhookWorkspaceDraftControllers() {
    final items = _webhooks?.items ?? const <OutboundWebhookListItemV1>[];
    final alive = items.map((e) => e.id).toSet();
    for (final id in _webhookWorkspaceDraftControllers.keys.toList()) {
      if (!alive.contains(id)) {
        _webhookWorkspaceDraftControllers.remove(id)?.dispose();
      }
    }
    for (final wh in items) {
      _webhookWorkspaceDraftControllers.putIfAbsent(
        wh.id,
        () => TextEditingController(text: wh.workspaceId ?? ''),
      );
    }
  }

  void _disposeAllWebhookWorkspaceDraftControllers() {
    for (final c in _webhookWorkspaceDraftControllers.values) {
      c.dispose();
    }
    _webhookWorkspaceDraftControllers.clear();
  }

  Future<void> _loadWebhooks() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _webhooksError = kProductShellSignInErrorPlaceholder;
        _webhooks = null;
      });
      _disposeAllWebhookWorkspaceDraftControllers();
      return;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
    });
    try {
      final resp = await getSettingsOutboundWebhookListV1(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooks = resp;
        _syncWebhookWorkspaceDraftControllers();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
        _webhooks = null;
      });
      _disposeAllWebhookWorkspaceDraftControllers();
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
        });
      }
    }
  }

  List<HelpHubLinkItemV1> _filteredHelpHubLinks() {
    final items = _resp?.items ?? const <HelpHubLinkItemV1>[];
    final needle = _helpHubSearchController.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return items;
    }
    return items
        .where((item) {
          final haystack = '${item.id} ${item.title} ${item.url}'.toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  String _helpHubCategorySlug(HelpHubLinkItemV1 item) {
    final key = '${item.id} ${item.title} ${item.url}'.toLowerCase();
    if (key.contains('runbook') || key.contains('guide')) {
      return 'runbook';
    }
    if (key.contains('webhook') || key.contains('billing')) {
      return 'billing';
    }
    if (key.contains('workspace') || key.contains('team')) {
      return 'workspace';
    }
    if (key.contains('quality') || key.contains('review')) {
      return 'quality';
    }
    if (key.contains('status') || key.contains('health')) {
      return 'status';
    }
    return 'general';
  }

  String _helpHubInventorySummary(AppLocalizations l10n) {
    final items = _resp?.items ?? const <HelpHubLinkItemV1>[];
    final filtered = _filteredHelpHubLinks();
    final counts = <String, int>{};
    for (final item in filtered) {
      final slug = _helpHubCategorySlug(item);
      counts.update(slug, (value) => value + 1, ifAbsent: () => 1);
    }
    final extra = counts.isEmpty
        ? ''
        : ' · ${counts.entries.map((e) => l10n.helpHubSummaryCategoryCount(_helpHubCategoryLabelForSlug(e.key, l10n), e.value)).join(', ')}';
    return l10n.helpHubSummary(items.length, filtered.length, extra);
  }

  String _helpHubCategoryLabelForSlug(String slug, AppLocalizations l10n) {
    switch (slug) {
      case 'runbook':
        return l10n.helpHubCategoryRunbook;
      case 'billing':
        return l10n.helpHubCategoryBillingWebhook;
      case 'workspace':
        return l10n.helpHubCategoryWorkspace;
      case 'quality':
        return l10n.helpHubCategoryQuality;
      case 'status':
        return l10n.helpHubCategoryStatus;
      default:
        return l10n.helpHubCategoryGeneral;
    }
  }

  BillingWebhookEventsQueryV1 _buildBillingEventsQuery({int offset = 0}) {
    return BillingWebhookEventsQueryV1(
      informationalEvent: _billingInformationalOnly,
      provider: _billingProvider,
      rawEventId: _billingRawEventIdController.text,
      rawEventIdPrefix: _billingRawEventIdPrefixController.text,
      eventType: _billingEventTypeController.text,
      providerEventId: _billingProviderEventIdController.text,
      providerEventIdPrefix: _billingProviderEventIdPrefixController.text,
      eventCreatedFrom: _billingEventCreatedFromController.text,
      eventCreatedTo: _billingEventCreatedToController.text,
      createdFrom: _billingCreatedFromController.text,
      createdTo: _billingCreatedToController.text,
      sort: _billingSort,
      limit: 30,
      offset: offset,
    );
  }

  Uri _billingEventsUri({int offset = 0}) {
    final query = _buildBillingEventsQuery(offset: offset);
    return Uri.parse(
      '$kApiBaseUrl/api/v1/webhooks/billing/events',
    ).replace(queryParameters: query.toQueryParameters());
  }

  Future<void> _loadBillingEvents({bool append = false}) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _billingEventsError = kProductShellSignInErrorPlaceholder;
        _billingEventsPage = null;
        _billingEvents.clear();
      });
      return;
    }
    setState(() {
      if (append) {
        _loadingMoreBillingEvents = true;
      } else {
        _loadingBillingEvents = true;
      }
      _billingEventsError = null;
    });
    try {
      final response = await getBillingWebhookEventsV1(
        token,
        query: _buildBillingEventsQuery(
          offset: append
              ? (_billingEventsPage?.nextOffset ?? _billingEvents.length)
              : 0,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _billingEventsPage = response;
        if (append) {
          _billingEvents.addAll(response.items);
        } else {
          _billingEvents
            ..clear()
            ..addAll(response.items);
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _billingEventsError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
        if (!append) {
          _billingEventsPage = null;
          _billingEvents.clear();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingBillingEvents = false;
          _loadingMoreBillingEvents = false;
        });
      }
    }
  }

  Future<void> _createWebhook() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final url = _webhookUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _webhooksError = l10n.opsWhErrorUrlRequired;
      });
      return;
    }
    final wsRaw = _webhookWorkspaceIdController.text.trim();
    String? workspaceId;
    if (wsRaw.isNotEmpty) {
      if (!outboundWebhookWorkspaceIdLooksValid(wsRaw)) {
        setState(() {
          _webhooksError = l10n.opsWhErrorWorkspaceId;
        });
        return;
      }
      workspaceId = wsRaw;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
    });
    try {
      final created = await postSettingsOutboundWebhookCreateV1(
        token,
        OutboundWebhookCreateBodyV1(
          url: url,
          secret: _webhookSecretController.text.trim().isEmpty
              ? null
              : _webhookSecretController.text.trim(),
          workspaceId: workspaceId,
          eventTypes: outboundWebhookEventTypesPayloadForCreate(
            _createWebhookEventTypes,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestCreatedWebhook = created;
        _webhookUrlController.clear();
        _webhookSecretController.clear();
        _webhookWorkspaceIdController.clear();
        _createWebhookEventTypes
          ..clear()
          ..addAll(kOutboundWebhookPlatformEventTypes);
        _appendWebhookActivity(
          action: 'created',
          webhookId: created.id,
          summary: created.url,
        );
      });
      await Clipboard.setData(ClipboardData(text: created.secret));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(context).opsWhSnackCreated,
          ),
        ),
      );
      await _loadWebhooks();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
        });
      }
    }
  }

  Future<void> _patchWebhookWorkspaceScope(String webhookId) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final ctrl = _webhookWorkspaceDraftControllers[webhookId];
    final draft = ctrl?.text.trim() ?? '';

    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
      _webhookBusyId = webhookId;
    });
    try {
      if (draft.isNotEmpty && !outboundWebhookWorkspaceIdLooksValid(draft)) {
        if (!mounted) {
          return;
        }
        setState(() {
          _webhooksError = resolveAppLocalizationsForErrors(
            context,
          ).opsWhErrorWorkspaceIdPatch;
        });
        return;
      }
      if (draft.isEmpty) {
        await patchSettingsOutboundWebhookV1(
          token,
          webhookId,
          const OutboundWebhookPatchBodyV1(clearWorkspaceId: true),
        );
      } else {
        await patchSettingsOutboundWebhookV1(
          token,
          webhookId,
          OutboundWebhookPatchBodyV1(workspaceId: draft),
        );
      }
      if (!mounted) {
        return;
      }
      final patchL10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.isEmpty
                ? patchL10n.opsWhSnackScopeGlobal
                : patchL10n.opsWhSnackScopeWorkspaceUpdated,
          ),
        ),
      );
      await _loadWebhooks();
      OutboundWebhookListItemV1? refreshed;
      final list = _webhooks?.items;
      if (list != null) {
        for (final w in list) {
          if (w.id == webhookId) {
            refreshed = w;
            break;
          }
        }
      }
      _webhookWorkspaceDraftControllers[webhookId]?.text =
          refreshed?.workspaceId ?? '';
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
          _webhookBusyId = null;
        });
      }
    }
  }

  Future<void> _patchWebhookEventSubscription(
    OutboundWebhookListItemV1 wh,
    Set<String> nextSelection,
  ) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
      _webhookBusyId = wh.id;
    });
    try {
      await patchSettingsOutboundWebhookV1(
        token,
        wh.id,
        OutboundWebhookPatchBodyV1(
          eventTypes: outboundWebhookEventTypesPayloadForPatch(nextSelection),
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(context).opsWhSnackEventsUpdated,
          ),
        ),
      );
      await _loadWebhooks();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
          _webhookBusyId = null;
        });
      }
    }
  }

  Future<void> _deleteWebhook(String id) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final confirmed = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dl10n = resolveAppLocalizationsForErrors(dialogContext);
        return StudioAlertDialog(
          title: Text(dl10n.opsWhDeleteTitle),
          content: SelectableText(dl10n.opsWhDeleteBody(id)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dl10n.notificationsActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dl10n.opsWhDeleteConfirmButton),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
      _webhookBusyId = id;
    });
    try {
      await deleteSettingsOutboundWebhookV1(token, id);
      if (!mounted) {
        return;
      }
      setState(() {
        _webhookLastTestResultById.remove(id);
        _webhookDeliveries.remove(id);
        _webhookWorkspaceDraftControllers.remove(id)?.dispose();
        if (_latestCreatedWebhook?.id == id) {
          _latestCreatedWebhook = null;
        }
        _appendWebhookActivity(
          action: 'deleted',
          webhookId: id,
          summary: resolveAppLocalizationsForErrors(context)
              .opsWhActivitySummaryDeleted,
        );
      });
      await _loadWebhooks();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
          _webhookBusyId = null;
        });
      }
    }
  }

  List<OutboundWebhookListItemV1> _filteredWebhooks() {
    final items = _webhooks?.items ?? const <OutboundWebhookListItemV1>[];
    final needle = _webhookSearchController.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return items;
    }
    return items
        .where((wh) {
          final haystack =
              '${wh.id} ${wh.url} ${wh.createdAt} ${wh.updatedAt ?? ''} ${wh.eventTypes.join(',')} ${wh.workspaceId ?? ''}'
                  .toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  Future<void> _loadWebhookDeliveries(String id) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _webhooksError = null;
      _loadingDeliveriesId = id;
    });
    try {
      final r = await getSettingsOutboundWebhookDeliveriesV1(
        token,
        id,
        limit: 30,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _webhookDeliveries[id] = r;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDeliveriesId = null;
        });
      }
    }
  }

  int _countWebhookActivity(String action) {
    return countWebhookActivity(
      _webhookActivity.map((entry) => entry.action),
      action,
    );
  }

  String _webhookInventorySummary(AppLocalizations l10n) {
    return buildWebhookInventorySummary(
      l10n,
      total: _webhooks?.items.length ?? 0,
      filtered: _filteredWebhooks().length,
      sessionTestOkCount: _countWebhookActivity('test_success'),
      sessionTestFailedCount: _countWebhookActivity('test_failed'),
      latestWebhookId: _latestCreatedWebhook?.id,
    );
  }

  void _appendWebhookActivity({
    required String action,
    required String webhookId,
    required String summary,
  }) {
    _webhookActivity.insert(
      0,
      _WebhookActivityEntry(
        at: DateTime.now(),
        action: action,
        webhookId: webhookId,
        summary: summary,
      ),
    );
    if (_webhookActivity.length > 20) {
      _webhookActivity.removeRange(20, _webhookActivity.length);
    }
  }

  Future<void> _testWebhook(String id) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
      _webhookBusyId = id;
    });
    try {
      final res = await postSettingsOutboundWebhookTestV1(
        token,
        id,
        OutboundWebhookTestBodyV1(
          eventType: _webhookTestEventTypeController.text.trim().isEmpty
              ? null
              : _webhookTestEventTypeController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _webhookLastTestResultById[id] = res;
        _appendWebhookActivity(
          action: res.delivered ? 'test_success' : 'test_failed',
          webhookId: id,
          summary: webhookActivityTestSummary(
            resolveAppLocalizationsForErrors(context),
            delivered: res.delivered,
            httpStatus: res.httpStatus,
            error: res.error,
          ),
        );
      });
      final testL10n = resolveAppLocalizationsForErrors(context);
      final httpLabel = res.httpStatus?.toString() ?? '-';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.delivered
                ? testL10n.opsWhSnackDeliverOk(httpLabel)
                : testL10n.opsWhSnackDeliverFail(
                    res.error?.trim().isNotEmpty == true
                        ? res.error!.trim()
                        : testL10n.globalSearchUnknownError,
                  ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
          _webhookBusyId = null;
        });
      }
    }
  }

  String _formatWebhookTestResult(
    AppLocalizations l10n,
    OutboundWebhookTestResponseV1 result,
  ) {
    final httpLabel = result.httpStatus?.toString() ?? '-';
    if (result.delivered) {
      return l10n.opsWhLastTestOk(httpLabel);
    }
    return l10n.opsWhLastTestFail(
      httpLabel,
      result.error?.trim().isNotEmpty == true
          ? result.error!.trim()
          : l10n.globalSearchUnknownError,
    );
  }

  String _formatBillingEventMeta(
    AppLocalizations l10n,
    BillingWebhookEventItemV1 item,
  ) {
    final parts = <String>[
      l10n.billingMetaProvider(item.provider ?? '-'),
      l10n.billingMetaType(item.eventType ?? '-'),
      l10n.billingMetaCreated(item.createdAt.toLocal().toIso8601String()),
    ];
    if (item.eventCreatedAt != null) {
      parts.add(
        l10n.billingMetaEventCreated(
          item.eventCreatedAt!.toLocal().toIso8601String(),
        ),
      );
    }
    parts.add(
      item.isInformationalEvent
          ? l10n.billingMetaInformational
          : l10n.billingMetaStateful,
    );
    return parts.join(' · ');
  }

  Map<String, int> _billingEventCountsByProvider(AppLocalizations l10n) {
    return countBillingEventsByProvider(l10n, _billingEvents);
  }

  Map<String, int> _billingEventCountsByType(AppLocalizations l10n) {
    return countBillingEventsByType(l10n, _billingEvents);
  }

  String _billingEventsSnapshotSummary(AppLocalizations l10n) {
    return buildBillingEventsSnapshotSummary(l10n, _billingEvents);
  }

  String _billingEventsQuerySummary(AppLocalizations l10n) {
    final parts = <String>[
      l10n.billingAuditQuerySummaryProvider(
        studioBillingProviderValueLabel(l10n, _billingProvider),
      ),
      l10n.billingAuditQuerySummaryInformational(
        studioBillingInformationalValueLabel(l10n, _billingInformationalOnly),
      ),
      l10n.billingAuditQuerySummarySort(
        studioBillingSortValueLabel(l10n, _billingSort),
      ),
    ];
    void addText(String fieldKey, TextEditingController controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        parts.add(
          l10n.billingAuditQueryFilterLine(
            studioBillingAuditQueryFieldLabel(l10n, fieldKey),
            value,
          ),
        );
      }
    }

    addText('event_type', _billingEventTypeController);
    addText('provider_event_id', _billingProviderEventIdController);
    addText(
      'provider_event_id_prefix',
      _billingProviderEventIdPrefixController,
    );
    addText('raw_event_id', _billingRawEventIdController);
    addText('raw_event_id_prefix', _billingRawEventIdPrefixController);
    addText('event_created_from', _billingEventCreatedFromController);
    addText('event_created_to', _billingEventCreatedToController);
    addText('created_from', _billingCreatedFromController);
    addText('created_to', _billingCreatedToController);
    return parts.join('\n');
  }

  String _buildBillingEventsCsv() {
    final rows = <List<String>>[
      <String>[
        'id',
        'provider_event_id',
        'provider',
        'raw_event_id',
        'event_type',
        'event_created_at',
        'created_at',
        'is_informational_event',
      ],
      ..._billingEvents.map(
        (item) => <String>[
          '${item.id}',
          item.providerEventId,
          item.provider ?? '',
          item.rawEventId ?? '',
          item.eventType ?? '',
          item.eventCreatedAt?.toUtc().toIso8601String() ?? '',
          item.createdAt.toUtc().toIso8601String(),
          item.isInformationalEvent ? 'true' : 'false',
        ],
      ),
    ];
    return rows.map(_toCsvLine).join('\n');
  }

  String _toCsvLine(List<String> cells) {
    return cells.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',');
  }

  Future<void> _copyBillingEventsQuerySummary() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    await Clipboard.setData(ClipboardData(text: _billingEventsQuerySummary(l10n)));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.billingAuditQuerySummaryCopied)),
    );
  }

  Future<void> _copyBillingEventsSnapshotSummary() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    await Clipboard.setData(
      ClipboardData(text: _billingEventsSnapshotSummary(l10n)),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.billingAuditSnapshotCopied)));
  }

  Future<void> _copyBillingAuditText(String text, String labelForSnack) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.billingCopiedWithLabel(labelForSnack))),
    );
  }

  Future<void> _applyBillingRowFilters({
    String? provider,
    String? eventType,
    String? providerEventId,
    String? rawEventId,
  }) async {
    setState(() {
      if (provider != null) {
        _billingProvider = provider.trim();
      }
      if (eventType != null) {
        _billingEventTypeController.text = eventType.trim();
      }
      if (providerEventId != null) {
        _billingProviderEventIdController.text = providerEventId.trim();
      }
      if (rawEventId != null) {
        _billingRawEventIdController.text = rawEventId.trim();
      }
    });
    await _loadBillingEvents();
  }

  Future<void> _copyAllBillingEventsCsv() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _billingEventsError = kProductShellSignInErrorPlaceholder;
      });
      return;
    }
    final exportL10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _exportingAllBillingEvents = true;
      _billingEventsError = null;
    });
    try {
      final all = <BillingWebhookEventItemV1>[];
      var offset = 0;
      const pageSize = 200;
      for (var page = 0; page < 20; page++) {
        final response = await getBillingWebhookEventsV1(
          token,
          query: BillingWebhookEventsQueryV1(
            informationalEvent: _billingInformationalOnly,
            provider: _billingProvider,
            rawEventId: _billingRawEventIdController.text,
            rawEventIdPrefix: _billingRawEventIdPrefixController.text,
            eventType: _billingEventTypeController.text,
            providerEventId: _billingProviderEventIdController.text,
            providerEventIdPrefix: _billingProviderEventIdPrefixController.text,
            eventCreatedFrom: _billingEventCreatedFromController.text,
            eventCreatedTo: _billingEventCreatedToController.text,
            createdFrom: _billingCreatedFromController.text,
            createdTo: _billingCreatedToController.text,
            sort: _billingSort,
            limit: pageSize,
            offset: offset,
          ),
        );
        all.addAll(response.items);
        if (!response.hasMore || response.nextOffset == null) {
          break;
        }
        offset = response.nextOffset!;
      }
      final rows = <List<String>>[
        <String>['query_summary', _billingEventsQuerySummary(exportL10n)],
        <String>[],
        <String>[
          'id',
          'provider_event_id',
          'provider',
          'raw_event_id',
          'event_type',
          'event_created_at',
          'created_at',
          'is_informational_event',
        ],
        ...all.map(
          (item) => <String>[
            '${item.id}',
            item.providerEventId,
            item.provider ?? '',
            item.rawEventId ?? '',
            item.eventType ?? '',
            item.eventCreatedAt?.toUtc().toIso8601String() ?? '',
            item.createdAt.toUtc().toIso8601String(),
            item.isInformationalEvent ? 'true' : 'false',
          ],
        ),
      ];
      await Clipboard.setData(
        ClipboardData(text: rows.map(_toCsvLine).join('\n')),
      );
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.billingAuditFullCsvCopied(all.length))),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _billingEventsError = describeUserVisibleApiError(
          resolveAppLocalizationsForErrors(context),
          e,
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _exportingAllBillingEvents = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final outboundWebhookEmptyMsg = _webhooks == null
        ? null
        : describeOutboundWebhookEmptyState(
            l10n,
            total: _webhooks!.items.length,
            filtered: _filteredWebhooks().length,
          );
    final billingWebhookEmptyMsg = describeBillingWebhookEmptyState(
      l10n,
      hasPage: _billingEventsPage != null,
      loaded: _billingEvents.length,
      isLoading: _loadingBillingEvents,
      error: _billingEventsError,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.helpHubDocsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.riskyPrefsTooltipSameAsMainPanelHeaders,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.helpHubLocalRiskLine,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _loading ? null : _load,
                child: Text(l10n.helpHubRefresh),
              ),
              OutlinedButton(
                onPressed: (_loading || _helpHubConfig == null)
                    ? null
                    : _openHelpHubManageDialog,
                child: Text(l10n.helpHubManageEntries),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) Text(l10n.helpHubLoading),
          if (_error != null)
            Text(
              _error == kProductShellSignInErrorPlaceholder
                  ? l10n.platformConfigPleaseSignIn
                  : _error!,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _helpHubSearchController,
            decoration: InputDecoration(labelText: l10n.helpHubSearchLabel),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (_resp != null) Text(_helpHubInventorySummary(l10n)),
          if (_resp != null && _resp!.items.isEmpty)
            Text(
              l10n.helpHubNoEffectiveLinks,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_resp != null &&
              _resp!.items.isNotEmpty &&
              _filteredHelpHubLinks().isEmpty)
            Text(
              l10n.helpHubSearchEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_resp != null)
            ..._filteredHelpHubLinks().map(
              (item) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Chip(
                        label: Text(
                          _helpHubCategoryLabelForSlug(
                            _helpHubCategorySlug(item),
                            l10n,
                          ),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(item.url),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          IconButton(
                            tooltip: l10n.helpHubCopyLinkTooltip,
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: item.url),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.helpHubCopied)),
                              );
                            },
                            icon: const Icon(Icons.copy),
                          ),
                          IconButton(
                            tooltip: l10n.helpHubCopyTitleUrlTooltip,
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: '${item.title}\n${item.url}',
                                ),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.helpHubCopiedHandoff),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_all_outlined),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l10n.opsWhSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookUrlController,
            decoration: InputDecoration(
              labelText: l10n.opsWhUrlLabel,
              hintText: l10n.opsWhUrlHint,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookSecretController,
            decoration: InputDecoration(labelText: l10n.opsWhSecretLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookWorkspaceIdController,
            decoration: InputDecoration(
              labelText: l10n.opsWhWorkspaceIdLabel,
              hintText: l10n.opsWhWorkspaceIdHint,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.opsWhSubscribeHint,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 4),
          OutboundWebhookEventChips(
            selected: _createWebhookEventTypes,
            enabled: !_loadingWebhooks,
            onSelectionChanged: (next) {
              setState(() {
                _createWebhookEventTypes
                  ..clear()
                  ..addAll(next);
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookTestEventTypeController,
            decoration: InputDecoration(
              labelText: l10n.opsWhTestEventTypeLabel,
              hintText: l10n.opsWhTestEventTypeHint,
            ),
          ),
          if (_latestCreatedWebhook != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.opsWhLatestCreatedTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.helpHubDialogClose,
                          onPressed: () {
                            setState(() {
                              _latestCreatedWebhook = null;
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    SelectableText(
                      l10n.opsWhFieldId(_latestCreatedWebhook!.id),
                    ),
                    SelectableText(
                      l10n.opsWhFieldUrl(_latestCreatedWebhook!.url),
                    ),
                    SelectableText(
                      l10n.opsWhFieldSecret(_latestCreatedWebhook!.secret),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.id),
                          ),
                          child: Text(l10n.opsWhCopyId),
                        ),
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.url),
                          ),
                          child: Text(l10n.opsWhCopyUrl),
                        ),
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.secret),
                          ),
                          child: Text(l10n.opsWhCopySecret),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _loadingWebhooks ? null : _createWebhook,
                child: Text(
                  _loadingWebhooks ? l10n.opsWhCreating : l10n.opsWhCreate,
                ),
              ),
              OutlinedButton(
                onPressed: _loadingWebhooks ? null : _loadWebhooks,
                child: Text(l10n.opsWhRefreshList),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookSearchController,
            decoration: InputDecoration(labelText: l10n.opsWhSearchLabel),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (_loadingWebhooks) Text(l10n.opsWhLoading),
          if (_webhooksError != null)
            Text(
              _webhooksError == kProductShellSignInErrorPlaceholder
                  ? l10n.platformConfigPleaseSignIn
                  : _webhooksError!,
              style: const TextStyle(color: Colors.red),
            ),
          if (_webhooks != null) Text(_webhookInventorySummary(l10n)),
          if (_webhookActivity.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.opsWhRecentActivity,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._webhookActivity
                .take(6)
                .map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.opsWhActivityEntryTitle(
                        webhookActivityActionLabel(l10n, entry.action),
                        entry.webhookId,
                      ),
                    ),
                    subtitle: SelectableText(
                      '${entry.at.toLocal().toIso8601String()}\n${entry.summary}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      tooltip: l10n.opsWhCopyActivityTooltip,
                      onPressed: () => _copyBillingAuditText(
                        '${webhookActivityActionLabel(l10n, entry.action)}\n'
                        '${entry.webhookId}\n'
                        '${entry.summary}',
                        l10n.opsWhActivityRecordSuffix.trim(),
                      ),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ),
                ),
          ],
          if (outboundWebhookEmptyMsg != null)
            Text(
              outboundWebhookEmptyMsg,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_webhooks != null)
            ..._filteredWebhooks().map(
              (wh) => Card(
                color: _latestCreatedWebhook?.id == wh.id
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wh.url,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      if (_latestCreatedWebhook?.id == wh.id)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Chip(
                            label: Text(l10n.opsWhChipLatestCreated),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      Text(l10n.opsWhFieldId(wh.id)),
                      Text(l10n.opsWhFieldCreatedAt(wh.createdAt)),
                      Text(
                        l10n.opsWhFieldUpdatedAt(wh.updatedAt ?? wh.createdAt),
                      ),
                      if (!wh.enabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Chip(
                            label: Text(l10n.opsWhChipDisabled),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.opsWhSubscribeHeading,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 4),
                            OutboundWebhookEventChips(
                              selected: outboundWebhookEffectiveSelection(
                                wh.eventTypes,
                              ),
                              enabled:
                                  !_loadingWebhooks && _webhookBusyId == null,
                              onSelectionChanged: (next) {
                                unawaited(
                                  _patchWebhookEventSubscription(wh, next),
                                );
                              },
                            ),
                            if (wh.eventTypes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  l10n.opsWhApiEventTypes(
                                    wh.eventTypes.join(', '),
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.opsWhScopeHeading,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller:
                                  _webhookWorkspaceDraftControllers[wh.id],
                              decoration: InputDecoration(
                                hintText: l10n.opsWhScopeFieldHint,
                                isDense: true,
                              ),
                              enabled:
                                  !_loadingWebhooks && _webhookBusyId == null,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed:
                                      _loadingWebhooks || _webhookBusyId != null
                                      ? null
                                      : () =>
                                            _patchWebhookWorkspaceScope(wh.id),
                                  child: Text(
                                    _webhookBusyId == wh.id
                                        ? l10n.opsWhSavingScope
                                        : l10n.opsWhSaveScope,
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      _loadingWebhooks || _webhookBusyId != null
                                      ? null
                                      : () {
                                          _webhookWorkspaceDraftControllers[wh
                                                  .id]
                                              ?.clear();
                                        },
                                  child: Text(l10n.opsWhClearInput),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_webhookDeliveries[wh.id] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.opsWhRecentDeliveries,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        ..._webhookDeliveries[wh.id]!.items
                            .take(6)
                            .map(
                              (d) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${d.eventType} · ${d.status} · HTTP ${d.httpStatus ?? '-'}',
                                ),
                                subtitle: SelectableText(
                                  '${d.createdAt}\n${d.error ?? ''}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                      ],
                      if (_webhookLastTestResultById[wh.id] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _formatWebhookTestResult(
                              l10n,
                              _webhookLastTestResultById[wh.id]!,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          IconButton(
                            tooltip: l10n.opsWhTooltipCopyUrl,
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: wh.url),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.opsWhUrlCopiedSnack),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined),
                          ),
                          OutlinedButton(
                            onPressed:
                                _loadingWebhooks || _webhookBusyId != null
                                ? null
                                : () => _testWebhook(wh.id),
                            child: Text(
                              _webhookBusyId == wh.id
                                  ? l10n.opsWhBusy
                                  : l10n.opsWhTestDeliver,
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                _loadingWebhooks ||
                                    _webhookBusyId != null ||
                                    _loadingDeliveriesId != null
                                ? null
                                : () => _loadWebhookDeliveries(wh.id),
                            child: Text(
                              _loadingDeliveriesId == wh.id
                                  ? l10n.opsWhLoading
                                  : l10n.opsWhDeliveryLog,
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                _loadingWebhooks || _webhookBusyId != null
                                ? null
                                : () => _deleteWebhook(wh.id),
                            child: Text(
                              _webhookBusyId == wh.id
                                  ? l10n.opsWhBusy
                                  : l10n.opsWhDelete,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final viewportWidth = MediaQuery.sizeOf(context).width;
              final billingDropdownWidth = viewportWidth < 1320 ? 220.0 : 240.0;
              final billingDateFieldWidth = viewportWidth < 1320
                  ? 240.0
                  : 280.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.billingAuditTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: billingDropdownWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _billingProvider,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditProviderLabel,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: '',
                              child: Text(l10n.billingAuditAll),
                            ),
                            DropdownMenuItem(
                              value: 'stripe',
                              child: Text(l10n.billingAuditProviderStripe),
                            ),
                            DropdownMenuItem(
                              value: 'alipay',
                              child: Text(l10n.billingAuditProviderAlipay),
                            ),
                            DropdownMenuItem(
                              value: 'paddle',
                              child: Text(l10n.billingAuditProviderPaddle),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _billingProvider = value ?? '';
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: billingDropdownWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _billingSort,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditSortLabel,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'id_desc',
                              child: Text(l10n.billingAuditSortNewest),
                            ),
                            DropdownMenuItem(
                              value: 'id_asc',
                              child: Text(l10n.billingAuditSortOldest),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _billingSort = value ?? 'id_desc';
                            });
                          },
                        ),
                      ),
                      FilterChip(
                        label: Text(l10n.billingAuditOnlyInformational),
                        selected: _billingInformationalOnly == true,
                        onSelected: (selected) {
                          setState(() {
                            _billingInformationalOnly = selected ? true : null;
                          });
                        },
                      ),
                      FilterChip(
                        label: Text(l10n.billingAuditOnlyStateful),
                        selected: _billingInformationalOnly == false,
                        onSelected: (selected) {
                          setState(() {
                            _billingInformationalOnly = selected ? false : null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingEventTypeController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditEventTypeLabel,
                      hintText: l10n.billingAuditEventTypeHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingProviderEventIdController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditProviderEventIdLabel,
                      hintText: l10n.billingAuditProviderEventIdHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingRawEventIdController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditRawEventIdLabel,
                      hintText: l10n.billingAuditRawEventIdHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingProviderEventIdPrefixController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditProviderEventIdPrefixLabel,
                      hintText: l10n.billingAuditProviderPrefixHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _billingRawEventIdPrefixController,
                    decoration: InputDecoration(
                      labelText: l10n.billingAuditRawEventIdPrefixLabel,
                      hintText: l10n.billingAuditRawPrefixHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: billingDateFieldWidth,
                        child: TextField(
                          controller: _billingEventCreatedFromController,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditEventCreatedFromLabel,
                            hintText: l10n.billingAuditEventCreatedFromHint,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: billingDateFieldWidth,
                        child: TextField(
                          controller: _billingEventCreatedToController,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditEventCreatedToLabel,
                            hintText: l10n.billingAuditEventCreatedToHint,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: billingDateFieldWidth,
                        child: TextField(
                          controller: _billingCreatedFromController,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditCreatedFromLabel,
                            hintText: l10n.billingAuditEventCreatedFromHint,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: billingDateFieldWidth,
                        child: TextField(
                          controller: _billingCreatedToController,
                          decoration: InputDecoration(
                            labelText: l10n.billingAuditCreatedToLabel,
                            hintText: l10n.billingAuditEventCreatedToHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _loadingBillingEvents ? null : _loadBillingEvents,
                child: Text(
                  _loadingBillingEvents
                      ? l10n.billingAuditQuerying
                      : l10n.billingAuditQuery,
                ),
              ),
              OutlinedButton(
                onPressed: _loadingBillingEvents || _loadingMoreBillingEvents
                    ? null
                    : () {
                        setState(() {
                          _billingProvider = '';
                          _billingInformationalOnly = null;
                          _billingSort = 'id_desc';
                          _billingEventTypeController.clear();
                          _billingProviderEventIdController.clear();
                          _billingProviderEventIdPrefixController.clear();
                          _billingRawEventIdController.clear();
                          _billingRawEventIdPrefixController.clear();
                          _billingEventCreatedFromController.clear();
                          _billingEventCreatedToController.clear();
                          _billingCreatedFromController.clear();
                          _billingCreatedToController.clear();
                        });
                        _loadBillingEvents();
                      },
                child: Text(l10n.billingAuditResetRefresh),
              ),
              OutlinedButton(
                onPressed: _billingEvents.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: _buildBillingEventsCsv()),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.billingAuditCsvCopiedSnack),
                          ),
                        );
                      },
                child: Text(l10n.billingAuditCopyCsv),
              ),
              OutlinedButton(
                onPressed: _copyBillingEventsQuerySummary,
                child: Text(l10n.billingAuditCopyQuerySummary),
              ),
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _billingEventsUri().toString()),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.billingAuditQueryUrlCopiedSnack),
                    ),
                  );
                },
                child: Text(l10n.billingAuditCopyQueryUrl),
              ),
              OutlinedButton(
                onPressed: _exportingAllBillingEvents
                    ? null
                    : _copyAllBillingEventsCsv,
                child: Text(
                  _exportingAllBillingEvents
                      ? l10n.billingAuditExporting
                      : l10n.billingAuditCopyFullCsv,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingBillingEvents) Text(l10n.billingAuditLoading),
          if (_billingEventsError != null)
            Text(
              _billingEventsError == kProductShellSignInErrorPlaceholder
                  ? l10n.platformConfigPleaseSignIn
                  : _billingEventsError!,
              style: const TextStyle(color: Colors.red),
            ),
          if (_billingEventsPage != null)
            Text(
              l10n.billingAuditPageStats(
                _billingEventsPage!.total,
                _billingEvents.length,
                '${_billingEventsPage!.hasMore}',
              ),
            ),
          if (billingWebhookEmptyMsg != null)
            Text(
              billingWebhookEmptyMsg,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_billingEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.billingAuditCurrentLoadTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(_billingEventCountsByProvider(l10n).entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .map(
                      (entry) => Chip(
                        label: Text(
                          l10n.billingChipCount(entry.key, entry.value),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                Chip(
                  label: Text(
                    l10n.billingSnapInformational(
                      _billingEvents
                          .where((e) => e.isInformationalEvent)
                          .length,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    l10n.billingSnapStateful(
                      _billingEvents
                          .where((e) => !e.isInformationalEvent)
                          .length,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(_billingEventCountsByType(l10n).entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .take(8)
                    .map(
                      (entry) => Chip(
                        label: Text(
                          l10n.billingChipCount(entry.key, entry.value),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                OutlinedButton(
                  onPressed: _copyBillingEventsSnapshotSummary,
                  child: Text(l10n.billingAuditCopySnapshot),
                ),
              ],
            ),
          ],
          ..._billingEvents.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.providerEventId,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(_formatBillingEventMeta(l10n, item)),
                    if (item.rawEventId != null && item.rawEventId!.isNotEmpty)
                      SelectableText(
                        l10n.billingRowRawEventId(item.rawEventId!),
                      ),
                    SelectableText(l10n.billingRowId('${item.id}')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _copyBillingAuditText(
                            item.providerEventId,
                            'provider_event_id',
                          ),
                          child: Text(l10n.billingAuditCopyProviderEventId),
                        ),
                        if (item.rawEventId != null &&
                            item.rawEventId!.isNotEmpty)
                          OutlinedButton(
                            onPressed: () => _copyBillingAuditText(
                              item.rawEventId!,
                              'raw_event_id',
                            ),
                            child: Text(l10n.billingAuditCopyRawEventId),
                          ),
                        if (item.provider != null &&
                            item.provider!.trim().isNotEmpty)
                          FilledButton.tonal(
                            onPressed: () => _applyBillingRowFilters(
                              provider: item.provider,
                            ),
                            child: Text(
                              l10n.billingAuditFilterByProvider(
                                item.provider!.trim(),
                              ),
                            ),
                          ),
                        if (item.eventType != null &&
                            item.eventType!.trim().isNotEmpty)
                          FilledButton.tonal(
                            onPressed: () => _applyBillingRowFilters(
                              eventType: item.eventType,
                            ),
                            child: Text(
                              l10n.billingAuditFilterByEventType(
                                item.eventType!.trim(),
                              ),
                            ),
                          ),
                        FilledButton.tonal(
                          onPressed: () => _applyBillingRowFilters(
                            providerEventId: item.providerEventId,
                            rawEventId: item.rawEventId,
                          ),
                          child: Text(l10n.billingAuditOnlyThisEvent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_billingEventsPage?.hasMore == true)
            OutlinedButton(
              onPressed: _loadingBillingEvents || _loadingMoreBillingEvents
                  ? null
                  : () => _loadBillingEvents(append: true),
              child: Text(
                _loadingMoreBillingEvents
                    ? l10n.opsWhLoading
                    : l10n.billingAuditLoadMore,
              ),
            ),
        ],
      ),
    );
  }
}
