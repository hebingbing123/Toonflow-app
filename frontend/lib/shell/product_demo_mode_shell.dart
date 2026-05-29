// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageProductDemoMode on _HomePageState {
  ProductDemoCatalog? get _activeDemoCatalog =>
      widget.debugPreviewData ??
      (ProductDemoMode.instance.isActive
          ? ProductDemoCatalog.buildDefault(
              resolveAppLocalizationsForErrors(context),
            )
          : null);

  bool get _hasDemoCatalog => _activeDemoCatalog != null;

  /// User-enabled tour mode (banner, guest token, mutation guards).
  bool get _isDemoModeActive => ProductDemoMode.instance.isActive;

  List<ScriptWorkbenchDetailRow>? get _storyboardDebugScripts =>
      _activeDemoCatalog?.storyboardDebugScripts;

  List<ProductionStoryboardItemV1>? get _storyboardDebugShots =>
      _activeDemoCatalog?.storyboardDebugShots;

  void _registerDemoModeListener() {
    ProductDemoMode.instance.addListener(_handleDemoModeChanged);
  }

  void _unregisterDemoModeListener() {
    ProductDemoMode.instance.removeListener(_handleDemoModeChanged);
  }

  void _handleDemoModeChanged() {
    if (!mounted) {
      return;
    }
    if (_isDemoModeActive) {
      _applyDemoSessionFromCatalog();
      // Prefs reload / extra HomePage mounts must not rewind an active tour.
      _configureDemoTour(forceRestart: false);
    } else {
      ProductDemoTour.instance.stop();
      _resetControllersAfterDemoExit();
    }
    setState(() {});
  }

  Future<void> _enterProductDemoMode({bool guest = false}) async {
    await ProductDemoMode.instance.enable(guest: guest);
    if (!mounted) {
      return;
    }
    _lastSessionAccessToken = null;
    _applyDemoSessionFromCatalog();
    // [enable] already notifies → [_handleDemoModeChanged] → [_configureDemoTour].
    // A second configure(forceRestart: true) here rewinds the tour to step 0 mid-flight.
    setState(() {});
  }

  /// Refresh GoRouter on each [HomePage] mount without rebinding [navigateStop].
  void _ensureDemoTourConfigured() {
    if (!_isDemoModeActive) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    ProductDemoTourShellNavigator.instance.updateRouter(router);
  }

  void _configureDemoTour({bool forceRestart = false}) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    _ensureDemoTourConfigured();
    final locale = Localizations.localeOf(context).languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isDemoModeActive) {
        return;
      }
      if (ProductDemoTour.instance.isEngaged) {
        _syncDemoTourFromShell();
      } else {
        ProductDemoTour.instance.enter(
          languageCode: locale,
          openFirstStop: true,
          interruptAutoplay: forceRestart,
          resetToFirstStop: true,
        );
      }
    });
  }

  Uri _demoTourEffectiveRouterUri() {
    return ProductDemoTour.effectiveRouteUri(GoRouterState.of(context).uri);
  }

  void _syncDemoTourFromShell() {
    if (!_isDemoModeActive) {
      return;
    }
    final routerUri = _demoTourEffectiveRouterUri();
    ProductDemoTour.instance.syncFromShell(
      uri: routerUri,
      overlay: widget.studioOverlay,
      projectNumericId:
          widget.studioProjectNumericId ?? _productScopedProjectNumericId,
      stepSlug: widget.studioStepSlug,
      pane: _shellNavigationController.productWorkspacePane,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

  // ignore: unused_element
  Future<void> _exitProductDemoMode() async {
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
    if (!mounted) {
      return;
    }
    _resetControllersAfterDemoExit();
    setState(() {});
    final token = _session?.accessToken;
    if (token != null && token.isNotEmpty) {
      unawaited(_syncSessionContext());
    }
  }

  void _resetControllersAfterDemoExit() {
    _projectsController.reset();
    _taskCenterController.reset();
    _jobsController.reset();
    _qualityReviewsController.reset();
    _notificationsController.reset();
    _apiKeysController.reset();
    _accountController.reset();
    _apiKeysController.skipDemoApi = false;
    _accountController.skipDemoApi = false;
    _workspaceRunController.skipDemoMutations = false;
    _workspaceWritebackController.skipDemoMutations = false;
    _skillsHarnessController.wsLog.clear();
    _workspaceOutputController.reset();
  }

  bool _applyDemoSessionFromCatalog() {
    final catalog = _activeDemoCatalog;
    if (catalog == null) {
      return false;
    }
    setState(() {
      _sessionMe = catalog.sessionMe;
      if (catalog.platformConfig != null) {
        _applyPlatformConfig(catalog.platformConfig!);
      }
      _loadingSessionMe = false;
      if (catalog.productScopedProjectNumericId != null) {
        _productScopedProjectNumericId = catalog.productScopedProjectNumericId;
      }
    });
    _applyDemoCatalogIfNeeded();
    _applyDemoRuntimeGuards();
    _ensureProductPaneData(_shellNavigationController.productWorkspacePane);
    return true;
  }

  void _applyDemoCatalogIfNeeded() {
    final data = _activeDemoCatalog;
    if (data == null) {
      return;
    }
    data.applyTo(
      projectsController: _projectsController,
      taskCenterController: _taskCenterController,
      jobsController: _jobsController,
      qualityReviewsController: _qualityReviewsController,
      notificationsController: _notificationsController,
      contentComplianceController: _contentComplianceController,
      apiKeysController: _apiKeysController,
      accountController: _accountController,
    );
    _seedAgentWorkspaceDemoFromCatalog(data);
    _applyDemoRuntimeGuards();
    if (data.productScopedProjectNumericId != null) {
      _productScopedProjectNumericId = data.productScopedProjectNumericId;
    }
  }

  void _seedAgentWorkspaceDemoFromCatalog(ProductDemoCatalog data) {
    final activity = data.agentWorkspaceSnapshot;
    if (activity != null) {
      _skillsHarnessController.applyDemoPreview(lines: activity.wsLogLines);
      _workspaceOutputController.applyDemoPreview(
        assistantText: activity.assistantText,
        lastToolResultLine: activity.lastToolResultLine,
        writebackLine: activity.writebackLine,
        suggestedFlowKey: activity.suggestedFlowKey,
      );
    }
  }

  void _applyDemoRuntimeGuards() {
    final active = _isDemoModeActive;
    _workspaceRunController.skipDemoMutations = active;
    _workspaceWritebackController.skipDemoMutations = active;
    if (!active || _activeDemoCatalog == null) {
      return;
    }
    _workspaceInputController.applyProjectScope(
      _activeDemoCatalog!.productScopedProjectNumericId ?? 7,
      projectUuid: demoProjectUuid,
      workspaceId: 'workspace-demo',
    );
    if (_workspaceInputController.scriptIdController.text.trim().isEmpty) {
      _workspaceInputController.scriptIdController.text = '3';
    }
  }
}
