// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

enum _StudioPaneUriHistoryMode {
  /// Web: [go] pushes browser history; desktop: [replace].
  auto,
  push,
  replace,
}

extension _HomePageProductShell on _HomePageState {
  static const bool _kStudioShellFourItems = true;

  /// Native macOS title-bar chrome only (Web must not touch `dart:io` [Platform]).
  static bool get _isMacOSNativeShell =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// VS Code-style single-row title bar (macOS / Windows / Linux native + Web).
  static bool _useIntegratedStudioTitleBar(double width) {
    if (width < _kMacOSIntegratedMinWidth) {
      return false;
    }
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  void _ensureProductPaneData(ProductWorkspacePane pane) {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    if (ProductDemoMode.instance.shouldSkipLiveApi) {
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
    _withStudioPaneRouteSyncSuppressed(() {
      _shellNavigationController.selectProductWorkspacePane(pane);
      _ensureProductPaneData(pane);
      if (kStudioPaneUriSyncedPanes.contains(pane)) {
        _syncProductWorkspacePaneUri(pane);
      }
    });
  }

  void _openSettingsModelVendorsTab() {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    StudioSettingsHubNavigation.requestApiModelsTab();
    setState(() => _settingsHubInitialTabIndex = 2);
    _selectProductUtilityPane(ProductWorkspacePane.account);
  }

  void _openBillingSubscribeFromShell({bool checkoutSuccess = false}) {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    StudioSettingsHubNavigation.requestPlanTab(
      openSubscribe: true,
      checkoutSuccess: checkoutSuccess,
    );
    setState(() => _settingsHubInitialTabIndex = 1);
    _selectProductUtilityPane(ProductWorkspacePane.account);
  }

  Future<void> _maybeNudgeDomesticVendorOnProjectsHome() async {
    if (!mounted || widget.shellMode != HomeShellMode.product) {
      return;
    }
    if (ProductDemoMode.instance.shouldSkipLiveApi) {
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

  /// Logo / explicit «回到项目首页» — clears in-app history.
  bool _hasTitleBarScopedProject() {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return false;
    }
    final projectUuid =
        _workspaceInputController.projectUuidController.text.trim().isEmpty
        ? null
        : _workspaceInputController.projectUuidController.text.trim();
    final label = productWorkspaceProjectLabel(
      l10n: l10n,
      projects: _projectsController.projects,
      projectNumericId: _productScopedProjectNumericId,
      projectUuid: projectUuid,
    );
    return label != null && label.trim().isNotEmpty;
  }

  /// Title-bar project line → shell projects home (replaces logo on macOS chrome).
  void _openTitleBarProjectHome() {
    if (widget.shellMode != HomeShellMode.product || !_hasTitleBarScopedProject()) {
      return;
    }
    final onShellHome = studioUriIsShellHome(GoRouterState.of(context).uri);
    _withStudioPaneRouteSyncSuppressed(() {
      if (!onShellHome) {
        GoRouter.of(context).go('/');
      }
      if (_shellNavigationController.productWorkspacePane !=
          ProductWorkspacePane.projects) {
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.projects,
        );
        _ensureProductPaneData(ProductWorkspacePane.projects);
      } else {
        _syncProductWorkspacePaneUri(ProductWorkspacePane.projects);
      }
    });
  }

  void _goToProjectsHome({bool clearNavigationHistory = true}) {
    if (clearNavigationHistory) {
      _shellNavigationController.resetProductWorkspacePaneHistory();
    }
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.projects) {
      if (clearNavigationHistory &&
          kStudioPaneUriSyncedPanes.contains(ProductWorkspacePane.projects)) {
        _withStudioPaneRouteSyncSuppressed(() {
          _syncProductWorkspacePaneUri(ProductWorkspacePane.projects);
        });
      }
      return;
    }
    _withStudioPaneRouteSyncSuppressed(() {
      if (clearNavigationHistory) {
        _shellNavigationController.replaceProductWorkspacePane(
          ProductWorkspacePane.projects,
        );
      } else {
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.projects,
        );
      }
      _ensureProductPaneData(ProductWorkspacePane.projects);
      if (kStudioPaneUriSyncedPanes.contains(ProductWorkspacePane.projects)) {
        _syncProductWorkspacePaneUri(ProductWorkspacePane.projects);
      }
    });
  }

  /// Pipeline / shell-home pane switches (records ←/→ history like utility panes).
  void _navigateShellProductWorkspacePane(ProductWorkspacePane pane) {
    if (!_isProductPaneEnabledForConfig(pane, _platformConfig)) {
      return;
    }
    _withStudioPaneRouteSyncSuppressed(() {
      _shellNavigationController.selectProductWorkspacePane(pane);
      _ensureProductPaneData(pane);
      if (kStudioPaneUriSyncedPanes.contains(pane)) {
        _syncProductWorkspacePaneUri(pane);
      }
    });
  }

  bool get _suppressStudioPaneRouteSync => _studioPaneRouteSyncSuppressCount > 0;

  /// While we [replace] the shell URI after pane back/forward/select, ignore route
  /// resync — otherwise [replaceProductWorkspacePane] clears the forward stack.
  void _withStudioPaneRouteSyncSuppressed(void Function() action) {
    _studioPaneRouteSyncSuppressCount++;
    try {
      action();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _studioPaneRouteSyncSuppressCount =
            (_studioPaneRouteSyncSuppressCount - 1).clamp(0, 1 << 30);
      });
    }
  }

  bool _popProductWorkspacePane() {
    final popped = _shellNavigationController.popProductWorkspacePane();
    if (!popped) {
      return false;
    }
    _withStudioPaneRouteSyncSuppressed(() {
      if (kIsWeb) {
        final router = GoRouter.maybeOf(context);
        if (router?.canPop() ?? false) {
          router!.pop();
          return;
        }
      }
      _syncProductWorkspacePaneUri(
        _shellNavigationController.productWorkspacePane,
        historyMode: _StudioPaneUriHistoryMode.replace,
      );
    });
    return true;
  }

  bool _forwardProductWorkspacePane() {
    final advanced = _shellNavigationController.forwardProductWorkspacePane();
    if (!advanced) {
      return false;
    }
    _withStudioPaneRouteSyncSuppressed(() {
      _syncProductWorkspacePaneUri(
        _shellNavigationController.productWorkspacePane,
        historyMode: _StudioPaneUriHistoryMode.replace,
      );
    });
    return true;
  }

  void _syncProductWorkspacePaneUri(
    ProductWorkspacePane pane, {
    _StudioPaneUriHistoryMode historyMode = _StudioPaneUriHistoryMode.auto,
  }) {
    if (!kStudioPaneUriSyncedPanes.contains(pane)) {
      return;
    }
    final uri = studioUriForUtilityPane(pane);
    final current = GoRouterState.of(context).uri.toString();
    if (current == uri) {
      return;
    }
    final router = GoRouter.of(context);
    final usePushHistory = switch (historyMode) {
      _StudioPaneUriHistoryMode.push => true,
      _StudioPaneUriHistoryMode.replace => false,
      _StudioPaneUriHistoryMode.auto => kIsWeb,
    };
    if (usePushHistory) {
      router.go(uri);
    } else {
      router.replace(uri);
    }
  }

  void _reconcileStudioPaneFromBrowserRoute(ProductWorkspacePane pane) {
    final nav = _shellNavigationController;
    if (nav.productWorkspacePane == pane) {
      return;
    }

    final forwardPeek = nav.productPaneForwardPeek;
    if (forwardPeek == pane) {
      nav.forwardProductWorkspacePane();
      _ensureProductPaneData(pane);
      return;
    }

    if (nav.rewindProductWorkspacePaneTo(pane)) {
      _ensureProductPaneData(pane);
      return;
    }

    nav.selectProductWorkspacePane(pane);
    _ensureProductPaneData(pane);
  }

  /// Leaves `/projects/…` (剧本/制作) and returns to shell home for the pane stack.
  void _exitProjectStudioRoute() {
    _withStudioPaneRouteSyncSuppressed(() {
      final nav = _shellNavigationController;
      if (nav.canGoBackProductWorkspacePane) {
        nav.popProductWorkspacePane();
      }
      final pane = nav.productWorkspacePane;
      final uri = kStudioPaneUriSyncedPanes.contains(pane)
          ? studioUriForUtilityPane(pane)
          : '/';
      final router = GoRouter.of(context);
      if (kIsWeb) {
        router.go(uri);
      } else {
        router.replace(uri);
      }
      _ensureProductPaneData(nav.productWorkspacePane);
    });
  }

  void _handleProductShellBack() {
    if (!studioUriIsShellHome(GoRouterState.of(context).uri)) {
      _exitProjectStudioRoute();
      return;
    }

    if (_shellNavigationController.canGoBackProductWorkspacePane) {
      if (_popProductWorkspacePane()) {
        return;
      }
    }
    final router = GoRouter.maybeOf(context);
    if (router?.canPop() ?? false) {
      router!.pop();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _handleProductShellForward() {
    if (_shellNavigationController.canGoForwardProductWorkspacePane) {
      _forwardProductWorkspacePane();
    }
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
          _navigateShellProductWorkspacePane(pane);
          return;
        }
        final step = pane == ProductWorkspacePane.scriptWorkspace
            ? StudioStep.script.slug
            : StudioStep.storyboard.slug;
        _withStudioPaneRouteSyncSuppressed(() {
          _shellNavigationController.selectProductWorkspacePane(pane);
          context.go('/projects/$projectId/$step');
        });
        return;
      case ProductWorkspacePane.projects:
        _goToProjectsHome(clearNavigationHistory: false);
        return;
      default:
        _navigateShellProductWorkspacePane(pane);
    }
  }

  void _syncStudioPaneFromRoute() {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    if (_suppressStudioPaneRouteSync) {
      return;
    }
    if (widget.studioOverlay != StudioOverlayMode.none) {
      return;
    }
    final uri = GoRouterState.of(context).uri;
    if (!studioUriIsShellHome(uri)) {
      return;
    }
    final tab = uri.queryParameters['tab']?.trim();
    if (tab == 'plan') {
      final checkout = uri.queryParameters['checkout']?.trim();
      _openBillingSubscribeFromShell(checkoutSuccess: checkout == 'success');
      return;
    }
    final pane = studioPaneFromUri(uri);
    _reconcileStudioPaneFromBrowserRoute(pane);
  }

  void _handleStudioRouteChanged() {
    if (!mounted) return;
    _syncStudioPaneFromRoute();
    if (_isDemoModeActive) {
      _syncDemoTourFromShell();
    }
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
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
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

  ProductShellMoreMenuGrouping _productShellMoreMenuGrouping(
    AppLocalizations l10n,
    double width,
  ) {
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
    return groupProductShellMoreMenuDestinations(secondary);
  }

  void _closeMacOSTitleBarMoreMenu() {
    if (!_macOSTitleBarMoreMenuOpen) {
      return;
    }
    setState(() => _macOSTitleBarMoreMenuOpen = false);
  }

  void _toggleMacOSTitleBarMoreMenu() {
    setState(() => _macOSTitleBarMoreMenuOpen = !_macOSTitleBarMoreMenuOpen);
  }

  void _applyProductShellMoreMenuSelection(ProductWorkspacePane selected) {
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

  Widget _buildProductShellMoreMenuContent(
    BuildContext ctx, {
    required AppLocalizations l10n,
    required ProductShellMoreMenuGrouping grouping,
    required bool compactActions,
    required double panelWidth,
    bool titleCentered = false,
    VoidCallback? onDismiss,
    void Function(ProductWorkspacePane pane)? onDestinationSelected,
  }) {
    final tokens = StudioTokens.of(ctx);
    final localeCode = AppLocaleNotifier.instance.code;
    final sectionLabelStyle = Theme.of(ctx).textTheme.labelSmall?.copyWith(
      color: tokens.textMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    const columnGap = 16.0;

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
          onTap: () {
            if (onDestinationSelected != null) {
              onDestinationSelected(dest.pane);
            } else {
              Navigator.of(ctx).pop(dest.pane);
            }
          },
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

    void dismissPanel() {
      if (onDismiss != null) {
        onDismiss();
      } else {
        Navigator.of(ctx).pop();
      }
    }

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: studioInsetPanelDecoration(ctx).copyWith(
          border: Border.all(
            color: tokens.primary.withValues(alpha: titleCentered ? 0.42 : 0),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: studioShadowColor(context, alpha: 0.16),
              blurRadius: 16,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
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
                  child: titleCentered
                      ? Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            Text(
                              l10n.productShellMoreMenu,
                              style: studioPaneTitleStyle(ctx),
                              textAlign: TextAlign.center,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: l10n.studioDismiss,
                                onPressed: dismissPanel,
                                style: studioUtilityIconButtonStyle(ctx),
                                icon: const Icon(Icons.close_rounded, size: 16),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                l10n.productShellMoreMenu,
                                style: studioPaneTitleStyle(ctx),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.studioDismiss,
                              onPressed: dismissPanel,
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
                        dismissPanel();
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
                      dismissPanel();
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
    final grouping = _productShellMoreMenuGrouping(l10n, width);
    final compactActions = width < 720;

    if (productShellMoreMenuUsesBottomSheet(width)) {
      final selected = await showStudioBottomSheet<ProductWorkspacePane>(
        context: anchorContext,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          final panelWidth = productShellMoreMenuPanelWidth(
            MediaQuery.sizeOf(ctx).width,
            horizontalMargin: 12,
          );
          return SafeArea(
            top: false,
            child: _buildProductShellMoreMenuContent(
              ctx,
              l10n: l10n,
              grouping: grouping,
              compactActions: compactActions,
              panelWidth: panelWidth,
            ),
          );
        },
      );
      if (selected == null || !mounted) {
        return;
      }
      _applyProductShellMoreMenuSelection(selected);
      return;
    }

    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final anchorBox = anchorContext.findRenderObject() as RenderBox;
    final anchorOffset = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final anchorRect = anchorOffset & anchorBox.size;
    final selected = await showGeneralDialog<ProductWorkspacePane>(
      context: anchorContext,
      barrierDismissible: true,
      barrierLabel: l10n.productShellMoreMenu,
      barrierColor: StudioTokens.of(anchorContext).overlay,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, animation1, animation2) {
        final mediaQuery = MediaQuery.of(ctx);
        final screenSize = mediaQuery.size;
        final horizontalMargin = 16.0;
        final safeTop = mediaQuery.padding.top + 10;
        final safeBottom = mediaQuery.padding.bottom + 12;
        final panelWidth = productShellMoreMenuPanelWidth(
          width,
          horizontalMargin: horizontalMargin,
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
    _applyProductShellMoreMenuSelection(selected);
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
    String pageTitle, {
    bool showPageTitle = true,
  }) {
    return InkWell(
      onTap: _goToProjectsHome,
      borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const OpenFlowBrandMark(size: 36, borderRadius: 10),
            const SizedBox(width: 16),
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
                  if (showPageTitle)
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

  /// VS Code–style macOS integrated title bar (38px shell, 30px search field).
  static const double _kMacOSTitleBarHeight = 38;
  static const double _kMacOSTitleBarInnerHeight = 30;
  /// Vertical padding when workspace context is shown (`microGap` top + 5 bottom).
  static const double _kMacOSTitleBarContextPaddingVertical =
      StudioLayoutSpacing.microGap + 5;
  static const double _kMacOSTitleBarInnerHeightWithContext = 38;
  static const double _kMacOSTitleBarHeightWithContext =
      _kMacOSTitleBarInnerHeightWithContext +
      _kMacOSTitleBarContextPaddingVertical;
  static const double _kTitleBarWorkspaceContextMaxWidth = 300;
  /// Reserved width for traffic lights + left drag target (macOS HIG ~12–14px margin).
  static const double _kMacOSTrafficLightInset = 72;

  /// Extra breathing room before title-bar workspace breadcrumb (after inset).
  static const double _kMacOSTitleBarGapAfterTrafficLights = 16;
  static const double _kMacOSIntegratedMinWidth =
      DesktopWindowConstraints.minWidth;

  static const double _kMacOSTitleBarIconSize = 17;
  static const double _kMacOSTitleBarIconBox = 28;

  ButtonStyle _macOSTitleBarIconStyle(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return IconButton.styleFrom(
      foregroundColor: tokens.textSecondary.withValues(alpha: 0.88),
      hoverColor: tokens.bgInset.withValues(alpha: 0.85),
      padding: EdgeInsets.zero,
      minimumSize: const Size(_kMacOSTitleBarIconBox, _kMacOSTitleBarIconBox),
      fixedSize: const Size(_kMacOSTitleBarIconBox, _kMacOSTitleBarIconBox),
      iconSize: _kMacOSTitleBarIconSize,
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
  }

  static const double _kMacOSNavChevronBox = 28;
  static const double _kMacOSNavChevronIcon = 18;

  Widget _buildMacOSNavChevronButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback? onPressed,
  }) {
    final tokens = StudioTokens.of(context);
    final color = enabled
        ? tokens.textSecondary.withValues(alpha: 0.92)
        : tokens.textMuted.withValues(alpha: 0.34);
    return SizedBox(
      width: _kMacOSNavChevronBox,
      height: _kMacOSNavChevronBox,
      child: IconButton(
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(
            _kMacOSNavChevronBox,
            _kMacOSNavChevronBox,
          ),
          fixedSize: const Size(
            _kMacOSNavChevronBox,
            _kMacOSNavChevronBox,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          foregroundColor: color,
          disabledForegroundColor: color,
          hoverColor: enabled
              ? tokens.bgInset.withValues(alpha: 0.75)
              : Colors.transparent,
        ),
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        icon: Icon(icon, size: _kMacOSNavChevronIcon, weight: 300),
      ),
    );
  }

  bool _canProductShellGoBack() {
    if (!studioUriIsShellHome(GoRouterState.of(context).uri)) {
      return true;
    }
    if (_shellNavigationController.canGoBackProductWorkspacePane) {
      return true;
    }
    final router = GoRouter.maybeOf(context);
    if (router?.canPop() ?? false) {
      return true;
    }
    return Navigator.of(context).canPop();
  }

  Widget _buildMacOSNavChevrons(BuildContext context) {
    return ListenableBuilder(
      listenable: _shellNavigationController,
      builder: (context, _) {
        final canBack = _canProductShellGoBack();
        final canForward =
            _shellNavigationController.canGoForwardProductWorkspacePane;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildMacOSNavChevronButton(
              context: context,
              icon: Icons.arrow_back,
              tooltip: 'Back',
              enabled: canBack,
              onPressed: canBack ? _handleProductShellBack : null,
            ),
            const SizedBox(width: 8),
            _buildMacOSNavChevronButton(
              context: context,
              icon: Icons.arrow_forward,
              tooltip: 'Forward',
              enabled: canForward,
              onPressed: canForward ? _handleProductShellForward : null,
            ),
          ],
        );
      },
    );
  }


  void _handleMacOSTitleBarPointerDown(PointerDownEvent event) {
    final now = DateTime.now();
    if (_macOSTitleBarLastPointerDownTime != null &&
        now.difference(_macOSTitleBarLastPointerDownTime!) <
            const Duration(milliseconds: 400)) {
      _macOSTitleBarLastPointerDownTime = null;
      _macOSTitleBarPointerDownPosition = null;
      unawaited(_toggleMacOSWindowZoom());
      return;
    }
    _macOSTitleBarLastPointerDownTime = now;
    _macOSTitleBarPointerDownPosition = event.position;
    _macOSTitleBarDragHandoff = false;
  }

  void _handleMacOSTitleBarPointerMove(PointerMoveEvent event) {
    if (_macOSTitleBarDragHandoff ||
        _macOSTitleBarPointerDownPosition == null ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    if ((event.position - _macOSTitleBarPointerDownPosition!).distance > 4) {
      _macOSTitleBarDragHandoff = true;
      unawaited(_startWindowDragging());
    }
  }

  void _handleMacOSTitleBarPointerUp(PointerUpEvent event) {
    _macOSTitleBarPointerDownPosition = null;
    _macOSTitleBarDragHandoff = false;
  }

  Widget _titleBarFlexibleGap() {
    if (_isMacOSNativeShell) {
      return _buildMacOSTitleBarDragRegion();
    }
    return const SizedBox.shrink();
  }

  /// Opaque drag/zoom target for macOS title-bar chrome (empty areas only).
  Widget _buildMacOSTitleBarDragRegion() {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handleMacOSTitleBarPointerDown,
      onPointerMove: _handleMacOSTitleBarPointerMove,
      onPointerUp: _handleMacOSTitleBarPointerUp,
      child: const ColoredBox(color: Color(0x00000000)),
    );
  }

  /// Navigation arrows hugging the left edge of the centered search field.
  Widget _buildMacOSTitleBarSearchCluster({
    required BuildContext context,
    required Widget searchBar,
    required bool moreMenuOpen,
    required double slotHeight,
  }) {
    final viewportWideEnoughForNavChevrons =
        MediaQuery.sizeOf(context).width >= 480 && slotHeight >= 32;
    const navChevronClusterWidth = _kMacOSNavChevronBox * 2 + 8;
    const searchFieldMinWidth = 120.0;
    return IgnorePointer(
      ignoring: moreMenuOpen,
      child: Opacity(
        opacity: moreMenuOpen ? 0 : 1,
        child: SizedBox(
          height: slotHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < searchFieldMinWidth) {
                return const SizedBox.shrink();
              }
              final showNavChevrons = viewportWideEnoughForNavChevrons &&
                  constraints.maxWidth >=
                      navChevronClusterWidth + searchFieldMinWidth;
              return Center(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (showNavChevrons) ...<Widget>[
                      _buildMacOSNavChevrons(context),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: searchBar),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  EdgeInsets _macOSTitleBarContentPadding({required bool hasWorkspaceContext}) {
    // Extra top inset: equal top/bottom reads visually high under traffic lights.
    return hasWorkspaceContext
        ? const EdgeInsets.only(left: 0, right: 10, top: StudioLayoutSpacing.microGap, bottom: 5)
        : const EdgeInsets.only(left: 0, right: 10, top: 5, bottom: 3);
  }

  Widget _buildMacOSTitleBarMoreMenuOverlay({
    required BuildContext context,
    required AppLocalizations l10n,
    required ProductShellMoreMenuGrouping grouping,
    required double titleBarHeight,
    required bool stackedTopChrome,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    const horizontalMargin = 16.0;
    final panelWidth = productShellMoreMenuPanelWidth(
      screenWidth,
      horizontalMargin: horizontalMargin,
    );
    final left = screenWidth - panelWidth - horizontalMargin;
    final top = stackedTopChrome
        ? titleBarHeight - 32
        : 4.0;
    final panelHeight = math.min(
      _estimateMoreMenuPanelHeight(
        panelWidth: panelWidth,
        grouping: grouping,
        compactActions: true,
      ),
      MediaQuery.sizeOf(context).height * 0.55,
    );

    return Positioned(
      top: top,
      left: left,
      width: panelWidth,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: panelHeight),
          child: _buildProductShellMoreMenuContent(
            context,
            l10n: l10n,
            grouping: grouping,
            compactActions: true,
            panelWidth: panelWidth,
            titleCentered: true,
            onDismiss: _closeMacOSTitleBarMoreMenu,
            onDestinationSelected: (pane) {
              _closeMacOSTitleBarMoreMenu();
              _applyProductShellMoreMenuSelection(pane);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMacOSTitleBarMoreButton(
    BuildContext context, {
    required AppLocalizations l10n,
    required bool moreMenuOpen,
  }) {
    return IconButton(
      style: _macOSTitleBarIconStyle(context),
      tooltip: l10n.productShellMoreMenu,
      onPressed: _toggleMacOSTitleBarMoreMenu,
      icon: Icon(
        moreMenuOpen ? Icons.apps : Icons.apps_rounded,
        size: _kMacOSTitleBarIconSize,
      ),
    );
  }

  Widget _buildMacOSIntegratedTitleBar({
    required BuildContext context,
    required AppLocalizations l10n,
    required Widget searchBar,
    required ProductWorkspacePane currentPane,
    required bool moreMenuOpen,
    required bool ultraNarrow,
    Widget? workspaceContext,
    required double innerHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const trailingChromeMin = _kMacOSTitleBarIconBox + 8;
        const searchClusterMin = 120.0;
        const interBlockGap = 16.0;
        var workspaceMaxWidth = _kTitleBarWorkspaceContextMaxWidth;
        if (workspaceContext != null) {
          final reserved = searchClusterMin +
              trailingChromeMin +
              interBlockGap +
              (ultraNarrow ? 0 : 160);
          workspaceMaxWidth = math.max(
            88,
            math.min(
              _kTitleBarWorkspaceContextMaxWidth,
              constraints.maxWidth - reserved,
            ),
          );
        }
        final searchCluster = Flexible(
          fit: FlexFit.loose,
          child: _buildMacOSTitleBarSearchCluster(
            context: context,
            searchBar: searchBar,
            moreMenuOpen: moreMenuOpen,
            slotHeight: innerHeight,
          ),
        );
        return SizedBox(
          height: innerHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (workspaceContext != null &&
                  workspaceMaxWidth >= 88) ...<Widget>[
                SizedBox(
                  height: innerHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: workspaceMaxWidth),
                      child: workspaceContext,
                    ),
                  ),
                ),
                const SizedBox(width: interBlockGap),
              ],
              Expanded(child: _titleBarFlexibleGap()),
              searchCluster,
              Expanded(child: _titleBarFlexibleGap()),
              if (!ultraNarrow) ...<Widget>[
                const SizedBox(width: 8),
                const StudioJobTray(),
                ProductDemoTourAnchor(
                  anchorId: ProductDemoTourAnchorIds.shellAppBar,
                  child: StudioAppBarActions(
                    dense: true,
                    selectedPane: currentPane,
                    unreadNotifications: _notificationsController.unreadCount,
                    onSelectPane: _selectProductUtilityPane,
                  ),
                ),
              ],
              _buildMacOSTitleBarMoreButton(
                context,
                l10n: l10n,
                moreMenuOpen: moreMenuOpen,
              ),
            ],
          ),
        );
      },
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
            ListenableBuilder(
              listenable: _shellNavigationController,
              builder: (context, _) {
                final canBack = _canProductShellGoBack();
                final canForward =
                    _shellNavigationController.canGoForwardProductWorkspacePane;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      style: studioChromeIconButtonStyle(context),
                      tooltip: 'Back',
                      onPressed: canBack ? _handleProductShellBack : null,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: studioChromeIconButtonStyle(context),
                      tooltip: 'Forward',
                      onPressed:
                          canForward ? _handleProductShellForward : null,
                      icon: const Icon(Icons.arrow_forward_ios, size: 22),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static const MethodChannel _macOSWindowChannel =
      MethodChannel('com.openflow.app/window');

  /// Start dragging the window (macOS only)
  Future<void> _startWindowDragging() async {
    if (!_isMacOSNativeShell) {
      return;
    }
    try {
      await _macOSWindowChannel.invokeMethod('startDragging');
    } catch (e) {
      // Silently fail if method channel is not available
      debugPrint('Failed to start window dragging: $e');
    }
  }

  /// Double-click title bar chrome → toggle macOS fullscreen (macOS only).
  Future<void> _toggleMacOSWindowZoom() async {
    if (!_isMacOSNativeShell) {
      return;
    }
    try {
      await _macOSWindowChannel.invokeMethod('toggleZoom');
    } catch (e) {
      debugPrint('Failed to toggle macOS window fullscreen: $e');
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
        onExploreDemo: () => unawaited(_enterProductDemoMode(guest: true)),
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
    final isMacOS = _isMacOSNativeShell;
    final handsetShellLayout = width < kStudioHandsetMaxWidth;
    final useMacOSIntegratedTitleBar =
        !handsetShellLayout && _useIntegratedStudioTitleBar(width);
    // Legacy multi-row chrome only when the viewport is too narrow for integrated.
    final compactTopChrome = handsetShellLayout ||
        (!useMacOSIntegratedTitleBar &&
            width < kStudioShellCompactTopChromeMaxWidth);
    final stackedTopChrome = !useMacOSIntegratedTitleBar &&
        width >= kStudioShellCompactTopChromeMaxWidth &&
        width < kStudioShellStackedTopChromeMaxWidth;
    final macOSUltraNarrowTitleBar = useMacOSIntegratedTitleBar &&
        width < kStudioShellMacOSUltraNarrowMaxWidth;
    // Scope summary stays in the title bar on every signed-in product pane.
    // [showPipeline] only controls the production step strip — not workspace context.
    final titleBarWorkspaceContext = _buildWorkspaceContextSection(
      context,
      inline: true,
      titleBarChrome: true,
      titleBarDense:
          handsetShellLayout ||
          compactTopChrome ||
          (useMacOSIntegratedTitleBar && macOSUltraNarrowTitleBar),
    );
    final titleBarLeftInset = isMacOS
        ? _kMacOSTrafficLightInset + _kMacOSTitleBarGapAfterTrafficLights
        : 16.0;
    final desktopWide = width >= 1440;
    final desktopXWide = width >= 1800;
    final shellHorizontalPadding = desktopXWide
        ? 14.0
        : desktopWide
        ? 12.0
        : 10.0;
    final shellSurfacePadding = handsetShellLayout
        ? 12.0
        : desktopXWide
        ? 22.0
        : desktopWide
        ? 18.0
        : 16.0;
    final shellPanelRadius = BorderRadius.circular(14);
    final globalSearchBar = GlobalSearchBar(
      accessToken: accessToken,
      currentWorkspaceName: _sessionMe?.currentWorkspace?.name,
      currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
      onNavigateToResults: _openGlobalSearchResults,
      compact: compactTopChrome || handsetShellLayout,
      titleBarDense: useMacOSIntegratedTitleBar || handsetShellLayout,
      showLocalPrefsMenu:
          !compactTopChrome && !useMacOSIntegratedTitleBar,
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
              const SizedBox(width: StudioSpacing.xs),
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
              const SizedBox(width: StudioSpacing.xs),
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

    final macOSMoreGrouping = useMacOSIntegratedTitleBar
        ? _productShellMoreMenuGrouping(l10n, width)
        : null;
    final macOSTitleBarUsesContext = useMacOSIntegratedTitleBar;
    final titleBarHeight = useMacOSIntegratedTitleBar
        ? (macOSTitleBarUsesContext
              ? _kMacOSTitleBarHeightWithContext
              : _kMacOSTitleBarHeight)
        : compactTopChrome
        ? (width < 560 ? 132.0 : 138.0)
        : stackedTopChrome
        ? 112.0
        : desktopXWide
        ? 78.0
        : desktopWide
        ? 72.0
        : 68.0;

    final macOSTitleBar = useMacOSIntegratedTitleBar
        ? SizedBox(
            height: titleBarHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.bgElevated,
                    border: Border(
                      bottom: BorderSide(
                        color: tokens.surfaceHighlight.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      if (isMacOS)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _kMacOSTrafficLightInset,
                          child: _buildMacOSTitleBarDragRegion(),
                        ),
                      Padding(
                        padding: _macOSTitleBarContentPadding(
                          hasWorkspaceContext: true,
                        ).copyWith(left: titleBarLeftInset),
                        child: _buildMacOSIntegratedTitleBar(
                          context: context,
                          l10n: l10n,
                          searchBar: globalSearchBar,
                          currentPane: currentPane,
                          moreMenuOpen: _macOSTitleBarMoreMenuOpen,
                          ultraNarrow: macOSUltraNarrowTitleBar,
                          workspaceContext: titleBarWorkspaceContext,
                          innerHeight: macOSTitleBarUsesContext
                              ? _kMacOSTitleBarInnerHeightWithContext
                              : _kMacOSTitleBarInnerHeight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : null;

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        macOSTitleBar ??
            GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: isMacOS ? (_) => _startWindowDragging() : null,
          onDoubleTap: isMacOS ? () => unawaited(_toggleMacOSWindowZoom()) : null,
          child: StudioGlassPanel(
            border: Border(
              bottom: BorderSide(
                color: tokens.surfaceHighlight.withValues(alpha: 0.84),
              ),
            ),
            padding: EdgeInsets.only(
              left: desktopXWide ? 24 : 16,
              right: desktopXWide ? 24 : 16,
              top: 0,
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
                              showPageTitle: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          moreMenuChrome,
                        ],
                      ),
                      const SizedBox(height: StudioLayoutSpacing.inlineGap - 2),
                      SizedBox(
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: titleBarWorkspaceContext,
                        ),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          _buildStudioLogoHeader(
                            context,
                            appTitle,
                            pageTitle,
                            showPageTitle: false,
                          ),
                          const SizedBox(width: 16),
                          Flexible(child: titleBarWorkspaceContext),
                          const SizedBox(width: 8),
                          _buildNavigationButtons(context),
                          const Spacer(),
                          const StudioJobTray(),
                          const SizedBox(width: 8),
                          ProductDemoTourAnchor(
                            anchorId: ProductDemoTourAnchorIds.shellAppBar,
                            child: StudioAppBarActions(
                              selectedPane: currentPane,
                              unreadNotifications:
                                  _notificationsController.unreadCount,
                              onSelectPane: _selectProductUtilityPane,
                            ),
                          ),
                          const SizedBox(width: 8),
                          moreMenuChrome,
                        ],
                      ),
                      const SizedBox(height: StudioLayoutSpacing.inlineGap),
                      Row(
                        children: <Widget>[
                          Expanded(child: globalSearchBar),
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _buildStudioLogoHeader(
                        context,
                        appTitle,
                        pageTitle,
                        showPageTitle: false,
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        flex: 2,
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: titleBarWorkspaceContext,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildNavigationButtons(context),
                      const SizedBox(width: 16),
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
                      ProductDemoTourAnchor(
                        anchorId: ProductDemoTourAnchorIds.shellAppBar,
                        child: StudioAppBarActions(
                          selectedPane: currentPane,
                          unreadNotifications:
                              _notificationsController.unreadCount,
                          onSelectPane: _selectProductUtilityPane,
                        ),
                      ),
                      const SizedBox(width: 8),
                      moreMenuChrome,
                    ],
                  ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: <Widget>[
              Padding(
            padding: EdgeInsets.fromLTRB(
              shellHorizontalPadding,
              StudioLayoutSpacing.stackMedium,
              shellHorizontalPadding,
              shellHorizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (showPipeline) ...<Widget>[
                  ProductDemoTourAnchor(
                    anchorId: ProductDemoTourAnchorIds.shellPipeline,
                    child: StudioPipelineStrip(
                      selectedPane: currentPane,
                      jobsPaneEnabled: _platformConfig.jobsPaneEnabled,
                      qualityPaneEnabled: _platformConfig.qualityDashboardEnabled,
                      compact: useCompactStudio || handsetShellLayout,
                      onSelectPane: _handleProductPipelinePaneSelect,
                    ),
                  ),
                  SizedBox(height: useCompactStudio ? 10 : 12),
                ],
                Expanded(
                  child: ProductDemoTourAnchor(
                    anchorId: ProductDemoTourAnchorIds.shellContent,
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
                ),
              ],
            ),
          ),
              if (useMacOSIntegratedTitleBar && _macOSTitleBarMoreMenuOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeMacOSTitleBarMoreMenu,
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final shellBody = useMacOSIntegratedTitleBar && macOSMoreGrouping != null
        ? Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              mainColumn,
              if (_macOSTitleBarMoreMenuOpen)
                _buildMacOSTitleBarMoreMenuOverlay(
                  context: context,
                  l10n: l10n,
                  grouping: macOSMoreGrouping,
                  titleBarHeight: titleBarHeight,
                  stackedTopChrome: false,
                ),
            ],
          )
        : mainColumn;

    final shell = Scaffold(
      backgroundColor: Colors.transparent,
      body: PopScope(
        canPop: !_canProductShellGoBack(),
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) {
            return;
          }
          _handleProductShellBack();
        },
        child: StudioShellBackdrop(child: shellBody),
      ),
    );

    Widget tree = StudioShellScope(
      onPopProductPane: _popProductWorkspacePane,
      onBackToProjectsHome: _goToProjectsHome,
      child: StudioJobScope(
        accessToken: accessToken,
        child: StudioCommandPaletteShortcuts(
          actions: _studioCommandActions(l10n),
          child: StudioOnboardingCoach(
            enabled:
                !_isDemoModeActive &&
                currentPane == ProductWorkspacePane.projects &&
                widget.studioOverlay == StudioOverlayMode.none,
            child: shell,
          ),
        ),
      ),
    );

    return tree;
  }
}
