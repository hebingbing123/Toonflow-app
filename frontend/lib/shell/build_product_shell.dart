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
          unawaited(
            _projectsController.loadProjects().then((_) async {
              await _applyDefaultProductProjectScopeIfNeeded();
            }),
          );
        case ProductWorkspacePane.notifications:
          unawaited(_notificationsController.refresh());
        case ProductWorkspacePane.jobs:
          unawaited(_jobsController.loadJobs());
        case ProductWorkspacePane.tasks:
          unawaited(_taskCenterController.loadTaskProjects());
          unawaited(_taskCenterController.loadTaskApi());
        case ProductWorkspacePane.quality:
          unawaited(_qualityReviewsController.loadQualityReviews());
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
    if (widget.shellMode == HomeShellMode.product &&
        (pane == ProductWorkspacePane.scriptWorkspace ||
            pane == ProductWorkspacePane.productionWorkspace)) {
      _handleProductPipelinePaneSelect(pane);
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

  void _openSettingsModelVendorsTab() {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    StudioSettingsHubNavigation.requestApiModelsTab();
    setState(() => _settingsHubInitialTabIndex = 2);
    _selectProductUtilityPane(ProductWorkspacePane.account);
  }

  Future<void> _maybeNudgeDomesticVendorOnProjectsHome() async {
    if (!mounted || widget.shellMode != HomeShellMode.product) {
      return;
    }
    if (widget.studioOverlay != StudioOverlayMode.none) {
      return;
    }
    if (_shellNavigationController.productWorkspacePane !=
        ProductWorkspacePane.projects) {
      return;
    }
    final token = _effectiveAccessToken?.trim();
    if (token == null || token.isEmpty) {
      return;
    }
    await DomesticVendorSetupNudge.maybeShowOnProjectsHome(
      context,
      accessToken: token,
      onOpenSettings: _openSettingsModelVendorsTab,
    );
  }

  void _goToProjectsHome() {
    _shellNavigationController.resetProductWorkspacePaneHistory();
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.projects) {
      return;
    }
    _shellNavigationController.replaceProductWorkspacePane(
      ProductWorkspacePane.projects,
    );
    _ensureProductPaneData(ProductWorkspacePane.projects);
    if (kStudioPaneUriSyncedPanes.contains(ProductWorkspacePane.projects)) {
      final uri = studioUriForUtilityPane(ProductWorkspacePane.projects);
      final current = GoRouterState.of(context).uri.toString();
      if (current != uri) {
        GoRouter.of(context).go(uri);
      }
    }
  }

  bool _popProductWorkspacePane() {
    final popped = _shellNavigationController.popProductWorkspacePane();
    if (!popped) {
      return false;
    }
    final pane = _shellNavigationController.productWorkspacePane;
    if (kStudioPaneUriSyncedPanes.contains(pane)) {
      final uri = studioUriForUtilityPane(pane);
      final current = GoRouterState.of(context).uri.toString();
      if (current != uri) {
        GoRouter.of(context).go(uri);
      }
    }
    return true;
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
    showStudioSnackBar(
      context,
      message: l10n.studioPipelineSelectProjectFirst,
      icon: Icons.folder_open_outlined,
    );
  }

  Future<void> _handleProductPipelinePaneSelect(
    ProductWorkspacePane pane,
  ) async {
    if (!_isProductPaneEnabledForConfig(pane, _platformConfig)) {
      return;
    }
    switch (pane) {
      case ProductWorkspacePane.scriptWorkspace:
      case ProductWorkspacePane.productionWorkspace:
        await _applyDefaultProductProjectScopeIfNeeded();
        if (!mounted) {
          return;
        }
        final projectId = _resolvedProductNumericIdForPipeline();
        if (projectId == null) {
          _promptSelectProjectFirst();
          _shellNavigationController.selectProductWorkspacePane(pane);
          return;
        }
        final step = pane == ProductWorkspacePane.scriptWorkspace
            ? StudioStep.script.slug
            : StudioStep.storyboard.slug;
        context.go('/projects/$projectId/$step');
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

  Widget _buildProductShellMoreMenuRow(
    BuildContext ctx, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool showCheckWhenSelected = true,
  }) {
    final tokens = StudioTokens.of(ctx);
    final labelStyle = Theme.of(ctx).textTheme.labelLarge?.copyWith(
      color: selected ? tokens.textPrimary : tokens.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
              color: selected
                  ? tokens.primarySoft.withValues(alpha: 0.72)
                  : tokens.bgSurface.withValues(alpha: 0.42),
              border: Border.all(
                color: selected
                    ? tokens.primary.withValues(alpha: 0.34)
                    : tokens.surfaceHighlight.withValues(alpha: 0.85),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: StudioLayoutSpacing.inlineGap,
              vertical: StudioLayoutSpacing.inlineGap - 1,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? tokens.accent : tokens.textSecondary,
                ),
                const SizedBox(width: StudioLayoutSpacing.inlineGap),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                if (selected && showCheckWhenSelected)
                  Icon(Icons.check_rounded, size: 16, color: tokens.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductShellMoreMenuContent(
    BuildContext ctx, {
    required AppLocalizations l10n,
    required ProductShellMoreMenuGrouping grouping,
    required bool compactActions,
    required double panelWidth,
  }) {
    final tokens = StudioTokens.of(ctx);
    final localeCode = AppLocaleNotifier.instance.code;
    final sectionLabelStyle = Theme.of(ctx).textTheme.labelSmall?.copyWith(
      color: tokens.textMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    const columnGap = StudioSpacing.sm;

    Widget destinationTile(
      ProductShellDestination dest, {
      required bool useTwoColumns,
      required double itemWidth,
    }) {
      final selected =
          _shellNavigationController.productWorkspacePane == dest.pane;
      return SizedBox(
        width: useTwoColumns ? itemWidth : double.infinity,
        child: _buildProductShellMoreMenuRow(
          ctx,
          label: dest.label(l10n),
          icon: dest.icon,
          selected: selected,
          onTap: () => Navigator.of(ctx).pop(dest.pane),
        ),
      );
    }

    Widget destinationSection({
      String? sectionLabel,
      required List<ProductShellDestination> destinations,
    }) {
      if (destinations.isEmpty) {
        return const SizedBox.shrink();
      }
      final useTwoColumns = panelWidth >= 360 && destinations.length >= 4;
      final itemWidth = useTwoColumns
          ? (panelWidth - (StudioLayoutSpacing.insetDense * 2) - columnGap) / 2
          : panelWidth - (StudioLayoutSpacing.insetDense * 2);
      final tiles = destinations
          .map(
            (dest) => destinationTile(
              dest,
              useTwoColumns: useTwoColumns,
              itemWidth: itemWidth,
            ),
          )
          .toList(growable: false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (sectionLabel != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              child: Text(sectionLabel, style: sectionLabelStyle),
            ),
          ],
          if (useTwoColumns)
            Wrap(spacing: columnGap, runSpacing: 0, children: tiles)
          else
            ...tiles,
        ],
      );
    }

    Widget sectionDivider() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Divider(height: 1, color: tokens.borderSubtle),
      );
    }

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: studioInsetPanelDecoration(ctx).copyWith(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              StudioLayoutSpacing.insetDense,
              StudioLayoutSpacing.inlineGap,
              StudioLayoutSpacing.insetDense,
              StudioLayoutSpacing.insetDense,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.productShellMoreMenu,
                          style: studioPaneTitleStyle(ctx),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.studioDismiss,
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: studioUtilityIconButtonStyle(ctx),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                destinationSection(destinations: grouping.quickAccess),
                if (grouping.workflow.isNotEmpty) ...<Widget>[
                  if (grouping.quickAccess.isNotEmpty) sectionDivider(),
                  destinationSection(
                    sectionLabel: l10n.productShellMoreMenuSectionWorkflow,
                    destinations: grouping.workflow,
                  ),
                ],
                if (grouping.platform.isNotEmpty) ...<Widget>[
                  sectionDivider(),
                  destinationSection(
                    sectionLabel: l10n.productShellMoreMenuSectionPlatform,
                    destinations: grouping.platform,
                  ),
                ],
                if (compactActions) ...<Widget>[
                  sectionDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                    child: Text(
                      l10n.localeSectionTitle,
                      style: sectionLabelStyle,
                    ),
                  ),
                  for (final option in <(String, String)>[
                    ('system', l10n.localeSystem),
                    ('en', l10n.localeEnglish),
                    ('zh', l10n.localeChinese),
                  ])
                    _buildProductShellMoreMenuRow(
                      ctx,
                      label: option.$2,
                      icon: Icons.language_outlined,
                      selected: localeCode == option.$1,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        unawaited(
                          AppLocaleNotifier.instance.setLocaleCode(option.$1),
                        );
                      },
                    ),
                  sectionDivider(),
                  _buildProductShellMoreMenuRow(
                    ctx,
                    label: l10n.authSignOut,
                    icon: Icons.logout_outlined,
                    selected: false,
                    showCheckWhenSelected: false,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      unawaited(_authController.signOut());
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _estimateMoreMenuPanelHeight({
    required double panelWidth,
    required ProductShellMoreMenuGrouping grouping,
    required bool compactActions,
  }) {
    int rowsFor(List<ProductShellDestination> list) {
      if (list.isEmpty) {
        return 0;
      }
      return panelWidth >= 360 && list.length >= 4
          ? (list.length / 2).ceil()
          : list.length;
    }

    var height = 56.0;
    if (grouping.quickAccess.isNotEmpty) {
      height += 8 + rowsFor(grouping.quickAccess) * 44;
    }
    if (grouping.workflow.isNotEmpty) {
      height += 28 + rowsFor(grouping.workflow) * 44;
    }
    if (grouping.platform.isNotEmpty) {
      height += 28 + rowsFor(grouping.platform) * 44;
    }
    if (compactActions) {
      height += 220;
    }
    return height;
  }

  Future<void> _openProductShellMoreMenu(BuildContext anchorContext) async {
    final l10n = AppLocalizations.of(anchorContext)!;
    final width = MediaQuery.sizeOf(anchorContext).width;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final anchorBox = anchorContext.findRenderObject() as RenderBox;
    final anchorOffset = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchorRect = anchorOffset & anchorBox.size;
    final secondaryRaw = <ProductShellDestination>[
      if (width < 720)
        ProductShellDestination(
          pane: ProductWorkspacePane.notifications,
          icon: Icons.notifications_outlined,
          selectedIcon: Icons.notifications,
          label: (_) => l10n.productNavNotifications,
        ),
      if (width < 720)
        ProductShellDestination(
          pane: ProductWorkspacePane.account,
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: (_) => l10n.studioAppBarSettings,
        ),
      if (width < 720)
        ProductShellDestination(
          pane: ProductWorkspacePane.helpHub,
          icon: Icons.help_outline,
          selectedIcon: Icons.help,
          label: (_) => l10n.studioAppBarHelp,
        ),
      ...(_kStudioShellFourItems
          ? studioShellSecondaryDestinations(
              l10n,
              jobsPaneEnabled: _platformConfig.jobsPaneEnabled,
              qualityPaneEnabled: _platformConfig.qualityDashboardEnabled,
            )
          : secondaryProductShellDestinations(l10n)),
    ];
    final seenPanes = <ProductWorkspacePane>{};
    final secondary = secondaryRaw
        .where((dest) => seenPanes.add(dest.pane))
        .toList(growable: false);
    final grouping = groupProductShellMoreMenuDestinations(secondary);
    final compactActions = width < 720;
    final selected = await showGeneralDialog<ProductWorkspacePane>(
      context: anchorContext,
      barrierDismissible: true,
      barrierLabel: l10n.productShellMoreMenu,
      barrierColor: StudioTokens.of(anchorContext).overlay,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, animation1, animation2) {
        final mediaQuery = MediaQuery.of(ctx);
        final screenSize = mediaQuery.size;
        final horizontalMargin = width < 720 ? 12.0 : 16.0;
        final safeTop = mediaQuery.padding.top + 10;
        final safeBottom = mediaQuery.padding.bottom + 12;
        final desiredWidth = width >= 1440
            ? 360.0
            : width >= 1100
            ? 340.0
            : width >= 720
            ? 320.0
            : screenSize.width - (horizontalMargin * 2);
        final panelWidth = math.min(
          desiredWidth,
          screenSize.width - (horizontalMargin * 2),
        );
        final estimatedHeight = _estimateMoreMenuPanelHeight(
          panelWidth: panelWidth,
          grouping: grouping,
          compactActions: compactActions,
        );
        final panelHeight = math.min(
          estimatedHeight,
          screenSize.height - safeTop - safeBottom,
        );
        final left = math.max(
          horizontalMargin,
          math.min(
            anchorRect.right - panelWidth,
            screenSize.width - panelWidth - horizontalMargin,
          ),
        );
        final top = math.max(
          safeTop,
          math.min(
            anchorRect.bottom + 10,
            screenSize.height - panelHeight - safeBottom,
          ),
        );

        return Stack(
          children: <Widget>[
            Positioned(
              left: left,
              top: top,
              width: panelWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: panelHeight),
                child: _buildProductShellMoreMenuContent(
                  ctx,
                  l10n: l10n,
                  grouping: grouping,
                  compactActions: compactActions,
                  panelWidth: panelWidth,
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.035),
              end: Offset.zero,
            ).animate(curved),
            child: child,
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

  /// Build browser-style navigation buttons (back/forward) for desktop
  Widget _buildNavigationButtons(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.surfaceHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              style: studioChromeIconButtonStyle(context),
              tooltip: 'Back',
              onPressed: () {
                // TODO: Implement navigation history back
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            ),
            const SizedBox(width: 4),
            IconButton(
              style: studioChromeIconButtonStyle(context),
              tooltip: 'Forward',
              onPressed: () {
                // TODO: Implement navigation history forward
              },
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// Start dragging the window (macOS only)
  Future<void> _startWindowDragging() async {
    if (!Platform.isMacOS) {
      return;
    }
    try {
      const channel = MethodChannel('com.openflow.app/window');
      await channel.invokeMethod('startDragging');
    } catch (e) {
      // Silently fail if method channel is not available
      debugPrint('Failed to start window dragging: $e');
    }
  }

  Widget _buildProductShellScaffold(BuildContext context, String? accessToken) {
    if (accessToken == null) {
      StudioToastOverlay.hide();
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
    final compactTopChrome = width < 860;
    final stackedTopChrome = width >= 860 && width < 1240;
    // Header chip when wide row (≥1440) or stacked second row (≥1120); block only if neither.
    final showHeaderWorkspaceContext = showPipeline &&
        !compactTopChrome &&
        (width >= 1440 || (stackedTopChrome && width >= 1120));
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
    final shellPanelRadius = BorderRadius.circular(StudioSpacing.radiusCard);
    final globalSearchBar = GlobalSearchBar(
      accessToken: accessToken,
      currentWorkspaceName: _sessionMe?.currentWorkspace?.name,
      currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
      onNavigateToResults: _openGlobalSearchResults,
      compact: compactTopChrome || stackedTopChrome,
      showLocalPrefsMenu: !compactTopChrome,
    );
    final moreMenuChrome = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.surfaceHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Builder(
              builder: (buttonContext) {
                return IconButton(
                  style: studioChromeIconButtonStyle(context),
                  tooltip: l10n.productShellMoreMenu,
                  onPressed: () => _openProductShellMoreMenu(buttonContext),
                  icon:
                      compactTopChrome &&
                          _notificationsController.unreadCount > 0
                      ? Badge.count(
                          count: _notificationsController.unreadCount,
                          child: const Icon(Icons.apps_outlined),
                        )
                      : const Icon(Icons.apps_outlined),
                );
              },
            ),
            if (!compactTopChrome) ...<Widget>[
              const SizedBox(width: StudioSpacing.chromeActionGap),
              StudioIconMenuButton<String>(
                style: studioChromeIconButtonStyle(context),
                tooltip: l10n.localeSectionTitle,
                icon: Icons.language_outlined,
                entries: <StudioMenuEntry<String>>[
                  StudioMenuEntry<String>(
                    value: 'system',
                    label: l10n.localeSystem,
                  ),
                  StudioMenuEntry<String>(
                    value: 'en',
                    label: l10n.localeEnglish,
                  ),
                  StudioMenuEntry<String>(
                    value: 'zh',
                    label: l10n.localeChinese,
                  ),
                ],
                onSelected: AppLocaleNotifier.instance.setLocaleCode,
              ),
              const SizedBox(width: StudioSpacing.chromeActionGap),
              IconButton(
                style: studioChromeIconButtonStyle(context),
                tooltip: l10n.authSignOut,
                onPressed: _authController.signOut,
                icon: const Icon(Icons.logout_outlined),
              ),
            ],
          ],
        ),
      ),
    );

    final isMacOS = Platform.isMacOS;
    final titleBarHeight = compactTopChrome
        ? (width < 560 ? 112.0 : 118.0)
        : stackedTopChrome
        ? 112.0
        : desktopXWide
        ? 78.0
        : desktopWide
        ? 72.0
        : 68.0;

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: isMacOS ? (_) => _startWindowDragging() : null,
          child: StudioGlassPanel(
            border: Border(
              bottom: BorderSide(
                color: tokens.surfaceHighlight.withValues(alpha: 0.84),
              ),
            ),
            padding: EdgeInsets.only(
              left: isMacOS && !compactTopChrome ? 78 : (desktopXWide ? 24 : desktopWide ? 20 : 16),
              right: desktopXWide ? 24 : desktopWide ? 20 : 16,
              top: isMacOS ? 8 : 0,
              bottom: 0,
            ),
            child: SizedBox(
              height: titleBarHeight,
              child: compactTopChrome
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _buildStudioLogoHeader(
                              context,
                              appTitle,
                              pageTitle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          moreMenuChrome,
                        ],
                      ),
                      const SizedBox(height: StudioLayoutSpacing.inlineGap),
                      Row(children: <Widget>[Expanded(child: globalSearchBar)]),
                    ],
                  )
                : stackedTopChrome
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _buildStudioLogoHeader(
                            context,
                            appTitle,
                            pageTitle,
                          ),
                          const SizedBox(width: 8),
                          _buildNavigationButtons(context),
                          const Spacer(),
                          const StudioJobTray(),
                          const SizedBox(width: 8),
                          StudioAppBarActions(
                            selectedPane: currentPane,
                            unreadNotifications:
                                _notificationsController.unreadCount,
                            onSelectPane: _selectProductUtilityPane,
                          ),
                          const SizedBox(width: StudioSpacing.xs),
                          moreMenuChrome,
                        ],
                      ),
                      const SizedBox(height: StudioLayoutSpacing.inlineGap),
                      Row(
                        children: <Widget>[
                          Expanded(child: globalSearchBar),
                          if (showHeaderWorkspaceContext) ...<Widget>[
                            const SizedBox(width: StudioLayoutSpacing.inlineGap),
                            SizedBox(
                              width: 250,
                              child: _buildWorkspaceContextSection(
                                context,
                                inline: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      _buildStudioLogoHeader(
                        context,
                        appTitle,
                        pageTitle,
                      ),
                      const SizedBox(width: 8),
                      _buildNavigationButtons(context),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: desktopXWide
                                ? 520
                                : desktopWide
                                ? 460
                                : 400,
                          ),
                          child: globalSearchBar,
                        ),
                      ),
                      const StudioJobTray(),
                      const SizedBox(width: 8),
                      if (showHeaderWorkspaceContext) ...<Widget>[
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: desktopXWide
                                ? 360
                                : desktopWide
                                ? 300
                                : 240,
                          ),
                          child: _buildWorkspaceContextSection(
                            context,
                            inline: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      StudioAppBarActions(
                        selectedPane: currentPane,
                        unreadNotifications:
                            _notificationsController.unreadCount,
                        onSelectPane: _selectProductUtilityPane,
                      ),
                      const SizedBox(width: StudioSpacing.xs),
                      moreMenuChrome,
                    ],
                  ),
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
                  if (!showHeaderWorkspaceContext) ...<Widget>[
                    _buildWorkspaceContextSection(
                      context,
                      compact: useCompactStudio,
                    ),
                    SizedBox(height: useCompactStudio ? 8 : 12),
                  ],
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
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.bgSurface.withValues(alpha: 0.96),
                      borderRadius: shellPanelRadius,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: ClipRRect(
                      borderRadius: shellPanelRadius,
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
                              children: <Widget>[
                                if (_error != null) ...<Widget>[
                                  StudioApiErrorCallout(
                                    error: _error!,
                                    emphasis:
                                        StudioApiErrorCalloutEmphasis.subtle,
                                    onDismiss: () =>
                                        setState(() => _error = null),
                                  ),
                                  const SizedBox(height: StudioLayoutSpacing.inlineGap),
                                ],
                                ..._buildActiveProductPaneWidgets(context),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final shell = Scaffold(
      backgroundColor: Colors.transparent,
      body: StudioShellBackdrop(child: mainColumn),
    );

    return StudioShellScope(
      onPopProductPane: _popProductWorkspacePane,
      onBackToProjectsHome: _goToProjectsHome,
      child: StudioJobScope(
        accessToken: accessToken,
        child: StudioCommandPaletteShortcuts(
          actions: _studioCommandActions(l10n),
          child: StudioOnboardingCoach(
            enabled:
                currentPane == ProductWorkspacePane.projects &&
                widget.studioOverlay == StudioOverlayMode.none,
            child: shell,
          ),
        ),
      ),
    );
  }
}
