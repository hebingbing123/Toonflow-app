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
    final projects = _projectsController.projects;
    if (projects == null || projects.isEmpty) {
      return;
    }

    final scopedNumericId =
        widget.studioProjectNumericId ?? _productScopedProjectNumericId;
    if (scopedNumericId != null && scopedNumericId > 0) {
      final scopedUuid = _workspaceInputController.projectUuidController.text
          .trim();
      if (scopedUuid.isEmpty) {
        ProjectRow? row;
        for (final candidate in projects) {
          if (candidate.numericId == scopedNumericId) {
            row = candidate;
            break;
          }
        }
        if (row != null) {
          await _selectProjectScope(row);
          return;
        }
      } else if (_productScopedProjectNumericId != null) {
        return;
      }
    }

    if (_productScopedProjectNumericId != null) {
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
    final hasProductProjectRoute =
        widget.shellMode == HomeShellMode.product &&
        link.projectNumericId != null &&
        link.projectNumericId! > 0;
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
    if (hasProductProjectRoute) {
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
        if (hasProductProjectRoute) {
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
        if (hasProductProjectRoute) {
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
    final needsProjectUuid =
        widget.studioOverlay == StudioOverlayMode.storyboardStudio ||
        widget.studioOverlay == StudioOverlayMode.episodeConsole;
    if (needsProjectUuid && effectiveProjectUuid.trim().isEmpty) {
      if (_projectsController.projects == null) {
        unawaited(_projectsController.loadProjects());
      }
      return <Widget>[const Center(child: CircularProgressIndicator())];
    }
    if (needsProjectUuid && token.isEmpty) {
      return <Widget>[const Center(child: CircularProgressIndicator())];
    }

    return buildStudioOverlayChildren(
      resolved: resolved,
      loadingChild: const Center(child: CircularProgressIndicator()),
      storyboardBuilder: (projectNumericId) => StoryboardStudioPage(
        projectNumericId: projectNumericId,
        projectUuid: effectiveProjectUuid,
        accessToken: token,
        onClose: () => context.go('/projects/$projectNumericId/script'),
        onOpenProductionWorkspace: ({required String projectUuid}) {
          _openShellPaneFromStudioOverlay(
            ProductWorkspacePane.productionWorkspace,
            projectNumericId: projectNumericId,
            projectUuid: projectUuid,
          );
        },
        onOpenShotEditor:
            ({
              required String projectUuid,
              required int scriptNumericId,
              required int storyboardNumericId,
            }) {
              return _openStoryboardEditor(
                token,
                storyboardNumericId,
                projectId: projectUuid,
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
                    _buildReadonlyProjectScopeRow(
                      projectNumericId: projectNumericId,
                      projectUuid: projectUuid,
                      projectName: effectiveProjectName,
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
              onOpenProjectSettings: () {
                final row = _studioProjectRowForNumericId(projectNumericId);
                if (row != null) _openProjectDetail(row);
              },
              onOpenGlobalModelVendorSettings: _openSettingsModelVendorsTab,
              buildStepBody: (step) => _buildProjectStudioStepBody(
                context,
                l10n,
                step,
                projectNumericId,
              ),
            ),
          ),
      reviewPackBuilder: (projectNumericId, projectUuid) =>
          StudioReviewPackScope(
            accessToken: token,
            projectNumericId: projectNumericId,
            projectUuid: projectUuid,
            projectName: effectiveProjectName,
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

  ProjectRow? _studioProjectRowForNumericId(int projectNumericId) {
    final existing = _studioProjectRow();
    if (existing != null) {
      return existing;
    }
    final uuid = _workspaceInputController.projectUuidController.text.trim();
    if (uuid.isEmpty) {
      return null;
    }
    return _buildReadonlyProjectScopeRow(
      projectNumericId: projectNumericId,
      projectUuid: uuid,
      projectName: widget.debugStudioProjectName,
    );
  }

  ProjectRow _buildReadonlyProjectScopeRow({
    required int projectNumericId,
    required String projectUuid,
    required String? projectName,
  }) {
    return ProjectRow(
      id: projectUuid,
      numericId: projectNumericId,
      name: projectName,
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
    );
  }

  Future<void> _studioScriptOpenNovelWorkbench(
    ProjectRow project,
    List<ListNovelsResponse?> novelsRef,
    List<bool> novelsBusy,
    Future<void> Function() reloadAssetsAndStats,
  ) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    await openNovelWorkbenchDialog(
      ctx: context,
      l10n: l10n,
      setDialogState: (fn) {
        if (mounted) setState(fn);
      },
      token: token,
      project: project,
      novelsRef: novelsRef,
      novelsBusy: novelsBusy,
      reloadAssetsAndStats: reloadAssetsAndStats,
      parseNumericIdList: parseNumericIdList,
      buildSearchSection: _buildNovelWorkbenchSearchSection,
      buildImportSection: _buildNovelWorkbenchImportSection,
      buildCreateSection: _buildNovelWorkbenchCreateSection,
      buildEditSection: _buildNovelWorkbenchEditSection,
      buildDeleteSection: _buildNovelWorkbenchDeleteSection,
      buildSnapshotSection: _buildNovelWorkbenchSnapshotSection,
    );
    await reloadAssetsAndStats();
    kStudioSnapshotBus.invalidate(StudioSnapshotInvalidation.workbenchMedia);
  }

  Future<void> _studioScriptOpenScriptsWorkbench(
    ProjectRow project,
    List<ScriptBrief> scriptList,
    List<bool> saving,
    List<bool> scriptTaskBusy,
    List<String?> scriptTaskLine,
    List<ProjectStats?> statsRef,
    Future<void> Function() reloadScripts,
  ) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    await openProjectScriptsWorkbenchDialog(
      ctx: context,
      l10n: l10n,
      setDialogState: (fn) {
        if (mounted) setState(fn);
      },
      token: token,
      project: project,
      saving: saving,
      scriptTaskBusy: scriptTaskBusy,
      scriptTaskLine: scriptTaskLine,
      scriptList: scriptList,
      statsRef: statsRef,
    );
    await reloadScripts();
    kStudioSnapshotBus.invalidate(StudioSnapshotInvalidation.workbenchMedia);
  }

  Widget _buildProjectStudioScriptStepBody(
    BuildContext context,
    int projectNumericId,
  ) {
    final token = _effectiveAccessToken;
    final project = _studioProjectRowForNumericId(projectNumericId);
    if (token == null ||
        token.isEmpty ||
        project == null ||
        project.id.isEmpty) {
      return Center(
        child: Text(
          resolveAppLocalizationsForErrors(
            context,
          ).studioScriptStepScopeMissing,
        ),
      );
    }

    final openNovelWorkbenchOnMount = _pendingStudioNovelWorkbench;
    if (openNovelWorkbenchOnMount) {
      _pendingStudioNovelWorkbench = false;
    }

    return ProjectStudioScriptStepPanel(
      accessToken: token,
      project: project,
      openNovelWorkbenchOnMount: openNovelWorkbenchOnMount,
      onOpenNovelWorkbench: (novelsRef, novelsBusy, reload) =>
          _studioScriptOpenNovelWorkbench(
            project,
            novelsRef,
            novelsBusy,
            reload,
          ),
      onOpenScriptsWorkbench:
          (
            scriptList,
            saving,
            scriptTaskBusy,
            scriptTaskLine,
            statsRef,
            reload,
          ) => _studioScriptOpenScriptsWorkbench(
            project,
            scriptList,
            saving,
            scriptTaskBusy,
            scriptTaskLine,
            statsRef,
            reload,
          ),
      onOpenPlanWorkbench: () => _openProjectScriptPlanWorkbenchDialog(
        ctx: context,
        token: token,
        project: project,
      ),
      onOpenBatchAddScripts: () async {
        final saving = <bool>[false];
        final scriptTaskLine = <String?>[null];
        final statsRef = <ProjectStats?>[null];
        final scriptList = <ScriptBrief>[];
        await _openBatchAddScriptsDialog(
          ctx: context,
          setDialogState: (fn) {
            if (mounted) setState(fn);
          },
          token: token,
          p: project,
          saving: saving,
          scriptTaskLine: scriptTaskLine,
          scriptList: scriptList,
          statsRef: statsRef,
        );
        kStudioSnapshotBus.invalidate(
          StudioSnapshotInvalidation.workbenchMedia,
        );
      },
      onOpenScriptEditor: (script) => _openScriptEditor(
        token,
        script.numericId,
        projectId: project.id,
        onScriptTreeMutated: () async {
          kStudioSnapshotBus.invalidate(
            StudioSnapshotInvalidation.workbenchMedia,
          );
        },
      ),
      onScriptSelected: (script) {
        _workspaceInputController.applyProjectScope(
          project.numericId,
          scriptNumericId: script.numericId,
          projectUuid: project.id,
        );
      },
      onContentChanged: () {
        kStudioSnapshotBus.invalidate(
          StudioSnapshotInvalidation.workbenchMedia,
        );
      },
      agentWorkspace: _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.script,
        sectionTitle: resolveAppLocalizationsForErrors(
          context,
        ).productAgentScriptWorkspaceTitle,
        sectionDescription: resolveAppLocalizationsForErrors(
          context,
        ).productAgentScriptWorkspaceSubtitle,
      ),
    );
  }

  Widget _buildProjectStudioStepBody(
    BuildContext context,
    AppLocalizations l10n,
    StudioStep step,
    int projectNumericId,
  ) {
    switch (step) {
      case StudioStep.script:
        return _buildProjectStudioScriptStepBody(context, projectNumericId);
      case StudioStep.art:
        final artRow = _studioProjectRowForNumericId(projectNumericId);
        final artToken = _effectiveAccessToken;
        if (artRow == null ||
            artToken == null ||
            artToken.isEmpty ||
            artRow.id.isEmpty) {
          return Center(child: Text(l10n.studioScriptStepScopeMissing));
        }
        return ProjectStudioArtStepPanel(
          accessToken: artToken,
          project: artRow,
          onProjectUpdated: (updated) {
            if (_projectsController.projects == null) {
              unawaited(_projectsController.loadProjects());
            } else {
              _projectsController.applyProjectRow(updated);
            }
            setState(() {});
          },
          onOpenProjectSettings: () => _openProjectDetail(artRow),
        );
      case StudioStep.assets:
        final pendingAssetId = _pendingStudioAssetNumericId;
        if (pendingAssetId != null) {
          _pendingStudioAssetNumericId = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final row = _studioProjectRowForNumericId(projectNumericId);
            if (row == null || !mounted) return;
            _openProjectAssetsWorkbenchFromStudio(
              row,
              ProjectStudioAssetEditorTarget(
                kind: ProjectStudioAssetEditorTargetKind.confirmCandidates,
                preferredAssetNumericId: pendingAssetId,
              ),
              onProjectSnapshotChanged: () async {
                kStudioSnapshotBus.invalidate(
                  StudioSnapshotInvalidation.workbenchMedia,
                );
              },
            );
          });
        }
        return _buildAgentWorkspacePane(
          initialPane: AgentWorkspacePane.production,
          sectionTitle: l10n.productAgentProductionWorkspaceTitle,
          sectionDescription: l10n.productAgentProductionWorkspaceSubtitle,
        );
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
            final row = _studioProjectRowForNumericId(projectNumericId);
            _openShellPaneFromStudioOverlay(
              ProductWorkspacePane.productionWorkspace,
              projectNumericId: projectNumericId,
              projectUuid:
                  row?.id ??
                  _workspaceInputController.projectUuidController.text.trim(),
            );
          },
          embeddedChild: _buildAgentWorkspacePane(
            initialPane: AgentWorkspacePane.production,
            sectionTitle: l10n.studioStepVideoTitle,
            sectionDescription: l10n.studioStepVideoBody,
          ),
        );
      case StudioStep.deliver:
        return _buildProjectStudioDeliverStepBody(
          context,
          l10n,
          projectNumericId: projectNumericId,
          initialTabIndex: 0,
        );
      case StudioStep.quality:
        return _buildProjectStudioDeliverStepBody(
          context,
          l10n,
          projectNumericId: projectNumericId,
          initialTabIndex: 2,
        );
    }
  }

  int _deliverTabIndexFromRoute(BuildContext context, {int fallback = 0}) {
    final tab = GoRouterState.of(context).uri.queryParameters['tab']?.trim();
    return switch (tab) {
      'quality' => 2,
      'publish' => 1,
      'assembly' => 0,
      _ => fallback,
    };
  }

  Widget _buildProjectStudioDeliverStepBody(
    BuildContext context,
    AppLocalizations l10n, {
    required int projectNumericId,
    int initialTabIndex = 0,
  }) {
    final tabIndex = _deliverTabIndexFromRoute(
      context,
      fallback: initialTabIndex,
    ).clamp(0, 2);
    return DefaultTabController(
      initialIndex: tabIndex,
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            dividerColor: Colors.transparent,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: <Tab>[
              Tab(height: 40, text: l10n.studioDeliverTabAssembly),
              Tab(height: 40, text: l10n.studioDeliverTabPublish),
              Tab(height: 40, text: l10n.studioDeliverTabQuality),
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
                      onOpenReviewPack: () =>
                          context.go('/projects/$projectNumericId/review-pack'),
                    ),
                    Expanded(
                      child: _buildShortVideoSpaceSection(
                        embedScope: ShortVideoSpaceEmbedScope.assembly,
                      ),
                    ),
                  ],
                ),
                _buildShortVideoSpaceSection(
                  embedScope: ShortVideoSpaceEmbedScope.publish,
                ),
                _buildShortVideoSpaceSection(
                  embedScope: ShortVideoSpaceEmbedScope.quality,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortVideoSpaceSection({
    ShortVideoSpaceEmbedScope embedScope = ShortVideoSpaceEmbedScope.full,
  }) {
    return ShortVideoSpaceSection(
      accessToken: _session?.accessToken,
      initialFocus: _shortVideoSpaceInitialFocus,
      embedScope: embedScope,
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
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.productComplianceOpenTargetFailed(
              describeUserVisibleApiErrorResolved(context, error),
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
                ? () =>
                      context.go('/projects/$projectId/${enterStudioStep.slug}')
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
          onOpenModelVendorSettings: widget.shellMode == HomeShellMode.product
              ? _openSettingsModelVendorsTab
              : null,
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
                initialTabIndex: _settingsHubInitialTabIndex,
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
