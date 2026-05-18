// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageProductShell on _HomePageState {
  static const bool _kStudioShellFourItems = true;

  void _ensureProductPaneData(ProductWorkspacePane pane) {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    void load() {
      if (!mounted) {
        return;
      }
      switch (pane) {
        case ProductWorkspacePane.projects:
          unawaited(_projectsController.loadProjects());
        case ProductWorkspacePane.notifications:
          unawaited(_notificationsController.refresh());
        case ProductWorkspacePane.jobs:
          unawaited(_jobsController.loadJobs());
        case ProductWorkspacePane.tasks:
          unawaited(_taskCenterController.loadTaskProjects());
        case ProductWorkspacePane.quality:
          unawaited(_qualityReviewsController.loadQualityDashboard());
        default:
          break;
      }
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      load();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => load());
    }
  }

  void _selectProductUtilityPane(ProductWorkspacePane pane) {
    if (!_isProductPaneEnabledForConfig(pane, _platformConfig)) {
      return;
    }
    _shellNavigationController.selectProductWorkspacePane(pane);
    _ensureProductPaneData(pane);
    if (kStudioPaneUriSyncedPanes.contains(pane)) {
      final uri = studioUriForUtilityPane(pane);
      final current = GoRouterState.of(context).uri.toString();
      if (current != uri) {
        GoRouter.of(context).go(uri);
      }
    }
  }

  void _goToProjectsHome() {
    _selectProductUtilityPane(ProductWorkspacePane.projects);
  }

  String _studioShellHeaderTitle(AppLocalizations l10n) {
    final row = _studioProjectRow();
    return resolveStudioShellHeaderTitle(
      l10n: l10n,
      overlayMode: widget.studioOverlay,
      projectName: row?.name,
      studioProjectNumericId: widget.studioProjectNumericId,
      productScopedProjectNumericId: _productScopedProjectNumericId,
      currentPane: _shellNavigationController.productWorkspacePane,
    );
  }

  int? _resolvedProductNumericIdForPipeline() {
    final scoped = _productScopedProjectNumericId;
    if (scoped != null && scoped > 0) {
      return scoped;
    }
    final parsed = int.tryParse(
      _workspaceInputController.projectIdController.text.trim(),
    );
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return null;
  }

  void _promptSelectProjectFirst() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.studioPipelineSelectProjectFirst)),
    );
  }

  void _handleProductPipelinePaneSelect(ProductWorkspacePane pane) {
    if (!_isProductPaneEnabledForConfig(pane, _platformConfig)) {
      return;
    }
    switch (pane) {
      case ProductWorkspacePane.scriptWorkspace:
        final projectId = _resolvedProductNumericIdForPipeline();
        if (projectId == null) {
          _promptSelectProjectFirst();
          return;
        }
        context.go('/projects/$projectId/${StudioStep.script.slug}');
        return;
      case ProductWorkspacePane.productionWorkspace:
        final projectId = _resolvedProductNumericIdForPipeline();
        if (projectId == null) {
          _promptSelectProjectFirst();
          return;
        }
        context.go('/projects/$projectId/${StudioStep.storyboard.slug}');
        return;
      case ProductWorkspacePane.projects:
        _goToProjectsHome();
        return;
      default:
        _shellNavigationController.selectProductWorkspacePane(pane);
        _ensureProductPaneData(pane);
        if (kStudioPaneUriSyncedPanes.contains(pane)) {
          final uri = studioUriForUtilityPane(pane);
          final current = GoRouterState.of(context).uri.toString();
          if (current != uri) {
            GoRouter.of(context).go(uri);
          }
        }
    }
  }

  void _syncStudioPaneFromRoute() {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    if (widget.studioOverlay != StudioOverlayMode.none) {
      return;
    }
    final uri = GoRouterState.of(context).uri;
    if (!studioUriIsShellHome(uri)) {
      return;
    }
    final pane = studioPaneFromUri(uri);
    if (_shellNavigationController.productWorkspacePane == pane) {
      return;
    }
    _shellNavigationController.selectProductWorkspacePane(pane);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureProductPaneData(pane);
    });
  }

  void _handleStudioRouteChanged() {
    if (!mounted) return;
    _syncStudioPaneFromRoute();
  }

  Future<void> _openProductShellMoreMenu(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final panelMaxWidth = width >= 1800
        ? 920.0
        : width >= 1440
        ? 760.0
        : width >= 1100
        ? 640.0
        : 520.0;
    final secondary = _kStudioShellFourItems
        ? studioShellSecondaryDestinations(
            l10n,
            jobsPaneEnabled: _platformConfig.jobsPaneEnabled,
            qualityPaneEnabled: _platformConfig.qualityDashboardEnabled,
          )
        : secondaryProductShellDestinations(l10n);
    final selected = await showModalBottomSheet<ProductWorkspacePane>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: BoxConstraints(maxWidth: panelMaxWidth),
      builder: (ctx) {
        final isWideDesktop = MediaQuery.sizeOf(ctx).width >= 1440;
        final headingStyle = studioPageTitleStyle(ctx);
        final subtitleStyle = studioSectionIntroStyle(ctx);
        final itemTitleStyle = studioPaneTitleStyle(ctx);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isWideDesktop ? 20 : 16,
              0,
              isWideDesktop ? 20 : 16,
              20,
            ),
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l10n.productShellMoreMenu, style: headingStyle),
                      const SizedBox(height: 6),
                      Text(
                        l10n.productPipelineStripTitle,
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                ),
                ...secondary.map(
                  (dest) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(dest.icon, size: 22),
                      title: Text(dest.label(l10n), style: itemTitleStyle),
                      selected:
                          _shellNavigationController.productWorkspacePane ==
                          dest.pane,
                      onTap: () => Navigator.of(ctx).pop(dest.pane),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    if (!_isProductPaneEnabledForConfig(selected, _platformConfig)) {
      return;
    }
    if (selected == ProductWorkspacePane.scriptWorkspace ||
        selected == ProductWorkspacePane.productionWorkspace) {
      _handleProductPipelinePaneSelect(selected);
      return;
    }
    if (kStudioPaneUriSyncedPanes.contains(selected)) {
      _selectProductUtilityPane(selected);
      return;
    }
    _shellNavigationController.selectProductWorkspacePane(selected);
    _ensureProductPaneData(selected);
  }

  List<StudioCommandAction> _studioCommandActions(AppLocalizations l10n) {
    return <StudioCommandAction>[
      StudioCommandAction(
        id: 'projects',
        label: l10n.productNavProjects,
        icon: Icons.folder_special_outlined,
        keywords: <String>['project', '项目'],
        onInvoke: _goToProjectsHome,
      ),
      StudioCommandAction(
        id: 'notifications',
        label: l10n.productNavNotifications,
        icon: Icons.notifications_outlined,
        keywords: <String>['notify', '通知'],
        onInvoke: () =>
            _selectProductUtilityPane(ProductWorkspacePane.notifications),
      ),
      StudioCommandAction(
        id: 'settings',
        label: l10n.productNavAccount,
        icon: Icons.settings_outlined,
        keywords: <String>['settings', '设置', 'account'],
        onInvoke: () => _selectProductUtilityPane(ProductWorkspacePane.account),
      ),
      StudioCommandAction(
        id: 'help',
        label: l10n.productNavHelp,
        icon: Icons.help_outline,
        keywords: <String>['help', '帮助'],
        onInvoke: () => _selectProductUtilityPane(ProductWorkspacePane.helpHub),
      ),
    ];
  }

  Widget _buildStudioLogoHeader(
    BuildContext context,
    String appTitle,
    String pageTitle,
  ) {
    return InkWell(
      onTap: _goToProjectsHome,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const OpenFlowBrandMark(size: 36, borderRadius: 10),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: studioChromeTitleStyle(
                      context,
                    )?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    pageTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: studioHintStyle(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductShellScaffold(BuildContext context, String? accessToken) {
    if (accessToken == null) {
      return ProductLoginPage(
        authController: _authController,
        errorMessage: _error,
        onSignIn: _authController.signIn,
        onSignUp: _authController.signUp,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final appTitle =
        _appL10n?.appTitle ??
        lookupAppLocalizations(const Locale('en')).appTitle;
    final pageTitle = _studioShellHeaderTitle(l10n);
    final useCompactStudio = _kStudioShellFourItems;
    final currentPane = _shellNavigationController.productWorkspacePane;
    final showPipeline = shouldShowStudioPipeline(
      overlayMode: widget.studioOverlay,
      currentPane: currentPane,
    );
    final width = MediaQuery.sizeOf(context).width;
    final desktopWide = width >= 1440;
    final desktopXWide = width >= 1800;
    final shellHorizontalPadding = desktopXWide
        ? 14.0
        : desktopWide
        ? 12.0
        : 10.0;
    final shellSurfacePadding = desktopXWide
        ? 22.0
        : desktopWide
        ? 18.0
        : 16.0;

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioGlassPanel(
          padding: EdgeInsets.symmetric(
            horizontal: desktopXWide
                ? 24
                : desktopWide
                ? 20
                : 16,
          ),
          child: SizedBox(
            height: desktopXWide
                ? 78
                : desktopWide
                ? 72
                : 68,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _buildStudioLogoHeader(context, appTitle, pageTitle),
                ),
                const StudioJobTray(),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: desktopXWide
                        ? 420
                        : desktopWide
                        ? 360
                        : 320,
                  ),
                  child: GlobalSearchBar(
                    accessToken: accessToken,
                    currentWorkspaceName: _sessionMe?.currentWorkspace?.name,
                    currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
                    onNavigateToResults: _openGlobalSearchResults,
                  ),
                ),
                const SizedBox(width: 8),
                StudioAppBarActions(
                  selectedPane: currentPane,
                  unreadNotifications: _notificationsController.unreadCount,
                  onSelectPane: _selectProductUtilityPane,
                ),
                IconButton(
                  tooltip: l10n.productShellMoreMenu,
                  onPressed: () => _openProductShellMoreMenu(context),
                  icon: const Icon(Icons.apps_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.localeSectionTitle,
                  icon: const Icon(Icons.language_outlined),
                  itemBuilder: (ctx) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'system',
                      child: Text(l10n.localeSystem),
                    ),
                    PopupMenuItem<String>(
                      value: 'en',
                      child: Text(l10n.localeEnglish),
                    ),
                    PopupMenuItem<String>(
                      value: 'zh',
                      child: Text(l10n.localeChinese),
                    ),
                  ],
                  onSelected: AppLocaleNotifier.instance.setLocaleCode,
                ),
                IconButton(
                  tooltip: l10n.authSignOut,
                  onPressed: _authController.signOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              shellHorizontalPadding,
              14,
              shellHorizontalPadding,
              shellHorizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (showPipeline) ...<Widget>[
                  _buildWorkspaceContextSection(
                    context,
                    compact: useCompactStudio,
                  ),
                  SizedBox(height: useCompactStudio ? 8 : 12),
                  StudioPipelineStrip(
                    selectedPane: currentPane,
                    jobsPaneEnabled: _platformConfig.jobsPaneEnabled,
                    qualityPaneEnabled: _platformConfig.qualityDashboardEnabled,
                    compact: useCompactStudio,
                    onSelectPane: _handleProductPipelinePaneSelect,
                  ),
                  SizedBox(height: useCompactStudio ? 12 : 16),
                ],
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    color: tokens.bgElevated,
                    child: widget.studioOverlay != StudioOverlayMode.none
                        ? Padding(
                            padding: EdgeInsets.all(shellSurfacePadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _buildStudioOverlayWidgets(context),
                            ),
                          )
                        : ListView(
                            padding: EdgeInsets.all(shellSurfacePadding),
                            children: _buildActiveProductPaneWidgets(context),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final shell = Scaffold(backgroundColor: tokens.bgBase, body: mainColumn);

    return StudioJobScope(
      accessToken: accessToken,
      child: StudioCommandPaletteShortcuts(
        actions: _studioCommandActions(l10n),
        child: shell,
      ),
    );
  }
}
