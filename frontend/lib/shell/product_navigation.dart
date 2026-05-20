// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

/// Product navigation extension for _HomePageState.
/// Handles deep links, navigation, and pane opening logic.
extension _HomePageProductNavigation on _HomePageState {
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

  int _deliverTabIndexFromRoute(BuildContext context, {int fallback = 0}) {
    final tab = GoRouterState.of(context).uri.queryParameters['tab']?.trim();
    return switch (tab) {
      'quality' => 2,
      'publish' => 1,
      'assembly' => 0,
      _ => fallback,
    };
  }
}
