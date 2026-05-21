// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

/// Product studio steps extension for _HomePageState.
/// Handles building UI for different studio steps (script, art, assets, etc.).
extension _HomePageProductStudioSteps on _HomePageState {
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
        child: StudioEmptyState.emptyData(
          title: resolveAppLocalizationsForErrors(
            context,
          ).studioScriptStepScopeMissing,
          icon: Icons.folder_off_outlined,
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
        suppressSectionHeader: true,
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
          return Center(
            child: StudioEmptyState.emptyData(
              title: l10n.studioScriptStepScopeMissing,
              icon: Icons.folder_off_outlined,
            ),
          );
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
}
