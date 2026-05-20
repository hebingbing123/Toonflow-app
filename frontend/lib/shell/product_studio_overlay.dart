// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

/// Product studio overlay extension for _HomePageState.
/// Handles studio overlay widgets and agent execution.
extension _HomePageProductStudioOverlay on _HomePageState {
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
}
