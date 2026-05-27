import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../product_shell/studio_shell_branches.dart';
import '../project_studio/project_studio_navigation.dart';
import '../project_studio/studio_overlay_mode.dart';
import '../project_studio/studio_step.dart';
import '../shell/navigation_controller.dart';
import 'product_demo_coach_overlay.dart';
import 'product_demo_mode.dart';
import 'product_demo_tour_anchors.dart';
import 'product_demo_tour_guide.dart';
import 'product_demo_tour_stops.dart';

export 'product_demo_coach_overlay.dart' show ProductDemoCoachStyle;
export 'product_demo_tour_guide.dart' show ProductDemoTourGuideSections;
export 'product_demo_tour_stops.dart' show kProductDemoTourBeatCount;

/// One guided beat on the product demo tour (route + coach copy + spotlight).
@immutable
class ProductDemoTourStop {
  const ProductDemoTourStop({
    required this.location,
    required this.titleZh,
    required this.titleEn,
    this.guideZh = '',
    this.guideEn = '',
    this.shortLabelZh,
    this.shortLabelEn,
    this.anchorId,
    this.coachStyle = ProductDemoCoachStyle.spotlight,
    this.dwell = const Duration(seconds: 4),
    this.sections,
    this.mainlineStep,
    this.mainlinePart,
    this.mainlinePartTotal,
    this.launchPart,
    this.launchPartTotal,
    this.isOptionalUtility = false,
  });

  final String location;
  final String titleZh;
  final String titleEn;
  final String guideZh;
  final String guideEn;
  final String? shortLabelZh;
  final String? shortLabelEn;
  final String? anchorId;
  final ProductDemoCoachStyle coachStyle;
  final Duration dwell;
  final ProductDemoTourGuideSections? sections;

  /// SOP main line 1–6 (script … deliver).
  final int? mainlineStep;

  /// Sub-beat within a studio step (e.g. storyboard 2/4).
  final int? mainlinePart;
  final int? mainlinePartTotal;

  /// Publish path sub-beat on short-video pane.
  final int? launchPart;
  final int? launchPartTotal;

  /// Tasks, notifications, etc. — not required to launch.
  final bool isOptionalUtility;

  String titleForLocale(String languageCode) =>
      languageCode.startsWith('zh') ? titleZh : titleEn;

  String guideForLocale(String languageCode) {
    final fromSections = sections?.compactBodyForLocale(languageCode);
    if (fromSections != null && fromSections.isNotEmpty) {
      return fromSections;
    }
    final plain = languageCode.startsWith('zh') ? guideZh : guideEn;
    return plain.isNotEmpty ? plain : (fromSections ?? '');
  }

  String shortLabelForLocale(String languageCode) {
    if (languageCode.startsWith('zh')) {
      return shortLabelZh ?? titleZh;
    }
    return shortLabelEn ?? titleEn;
  }

  bool get hasRichGuide => sections != null;
}

/// Shell-aware navigation for a tour stop (select project scope, then [go]).
typedef ProductDemoTourNavigateStop = Future<void> Function(String location);

/// Manual step-by-step guidance + optional timed auto-tour for demo mode.
class ProductDemoTour extends ChangeNotifier {
  ProductDemoTour._();

  static final ProductDemoTour instance = ProductDemoTour._();

  static const int kDemoProjectNumericId = 7;
  static const int kDemoStoryboardScriptNumericId = 3;

  GoRouter? _router;
  ProductDemoTourNavigateStop? _navigateStop;
  int _autoplayGeneration = 0;
  int _index = 0;
  bool _engaged = false;
  bool _isAutoplaying = false;
  bool _autoplayPaused = false;
  /// While set, [syncFromShell] must not rewind [ _index ] from a stale URI.
  int? _lockedStepIndex;
  /// Bumps on each [_goToIndex]; stale navigations must not overwrite [ _index ].
  int _navigationEpoch = 0;
  /// After manual next/prev, ignore [syncFromShell] while the shell URI catches up.
  DateTime? _suppressSyncUntil;
  /// Serializes manual next/prev so rapid taps do not interleave [_goToIndex].
  Future<void>? _manualStepChain;
  String _languageCode = 'zh';
  List<ProductDemoTourStop> _stops = buildDefaultStops();

  bool get isEngaged => _engaged;
  bool get isAutoplaying => _isAutoplaying;
  bool get isAutoplayPaused => _autoplayPaused;
  bool get isPlaying => _isAutoplaying;
  bool get isPaused => _autoplayPaused;
  int get stepIndex => _index;
  int get stepCount => _stops.length;
  ProductDemoTourStop? get currentStop =>
      _stops.isEmpty ? null : _stops[_index.clamp(0, _stops.length - 1)];
  String? get currentStepLabel => currentStop?.shortLabelForLocale(_languageCode);
  String? get currentGuideTitle => currentStop?.titleForLocale(_languageCode);
  String? get currentGuideBody => currentStop?.guideForLocale(_languageCode);

  ProductDemoTourGuideSections? get currentGuideSections => currentStop?.sections;

  String get languageCode => _languageCode;

  static List<ProductDemoTourStop> buildDefaultStops() => buildProductDemoTourStops();

  void configure(
    GoRouter router, {
    ProductDemoTourNavigateStop? navigateStop,
    bool clearNavigateStop = false,
  }) {
    _router = router;
    if (clearNavigateStop) {
      _navigateStop = null;
    } else if (navigateStop != null) {
      _navigateStop = navigateStop;
    }
  }

  /// On Flutter Web hash routes, [GoRouterState.uri] may stay `/` while
  /// [Uri.base.fragment] holds `#/projects/…`.
  static Uri effectiveRouteUri(Uri routerUri) {
    if (!kIsWeb) {
      return routerUri;
    }
    final frag = Uri.base.fragment.trim();
    if (frag.isEmpty) {
      return routerUri;
    }
    final normalized = frag.startsWith('/') ? frag : '/$frag';
    try {
      return Uri.parse(normalized);
    } catch (_) {
      return routerUri;
    }
  }

  /// Align tour index when the user changes the in-studio SOP step (journey strip).
  void syncFromProjectStudioStep({
    required int projectNumericId,
    required StudioStep step,
    String? languageCode,
  }) {
    if (!ProductDemoMode.instance.isActive || _isAutoplaying) {
      return;
    }
    if (_suppressSyncUntil != null &&
        DateTime.now().isBefore(_suppressSyncUntil!)) {
      return;
    }
    if (languageCode != null) {
      _languageCode = languageCode;
    }
    final location = projectStudioStepUri(
      projectNumericId,
      step,
      storyboardScriptNumericId: step == StudioStep.storyboard
          ? kDemoStoryboardScriptNumericId
          : null,
    ).toString();
    final matched = _indexForLocation(location);
    if (matched == null || matched == _index) {
      return;
    }
    if (_lockedStepIndex != null) {
      final lock = _lockedStepIndex!.clamp(0, _stops.length - 1);
      if (_engaged && matched < lock) {
        return;
      }
      _lockedStepIndex = null;
    }
    if (_engaged && !_isAutoplaying && matched < _index) {
      return;
    }
    _index = matched;
    notifyListeners();
  }

  /// Enter demo tour in **manual** mode (guided banner, no auto-advance).
  void enter({
    String languageCode = 'zh',
    List<ProductDemoTourStop>? stops,
    bool openFirstStop = true,
    bool interruptAutoplay = true,
    bool resetToFirstStop = true,
  }) {
    if (!ProductDemoMode.instance.isActive) {
      return;
    }
    if (interruptAutoplay) {
      stopAutoplay();
    }
    final wasEngaged = _engaged;
    final indexBeforeEnter = _index;
    _stops = stops ?? buildDefaultStops();
    _languageCode = languageCode;
    _engaged = true;
    final rewindToStart =
        resetToFirstStop && !(wasEngaged && indexBeforeEnter > 0);
    if (rewindToStart) {
      _lockedStepIndex = null;
      _index = 0;
    }
    notifyListeners();
    if (openFirstStop &&
        rewindToStart &&
        _router != null &&
        _stops.isNotEmpty &&
        !_routerMatchesStop(0)) {
      unawaited(_goToIndex(0));
    }
  }

  void syncFromShell({
    required Uri uri,
    required StudioOverlayMode overlay,
    required int? projectNumericId,
    required String? stepSlug,
    required ProductWorkspacePane pane,
    String? languageCode,
  }) {
    if (!ProductDemoMode.instance.isActive || _isAutoplaying) {
      return;
    }
    if (_suppressSyncUntil != null &&
        DateTime.now().isBefore(_suppressSyncUntil!)) {
      return;
    }
    if (languageCode != null) {
      _languageCode = languageCode;
    }
    final effectiveUri = effectiveRouteUri(uri);
    final location = _locationKeyFromShell(
      uri: effectiveUri,
      overlay: overlay,
      projectNumericId: projectNumericId,
      stepSlug: stepSlug,
      pane: pane,
    );
    final uriForMatch = Uri.parse(location);

    if (_lockedStepIndex != null) {
      final lock = _lockedStepIndex!.clamp(0, _stops.length - 1);
      final expected = Uri.parse(_stops[lock].location);
      if (_locationsEquivalent(uriForMatch, expected)) {
        _lockedStepIndex = null;
        notifyListeners();
        return;
      }
      final manual = _indexForShellContext(location, pane);
      if (manual != null && manual != lock) {
        if (_isStaleUriWhileNavigatingForward(uriForMatch, lock)) {
          return;
        }
        if (_engaged && manual < lock) {
          return;
        }
        _lockedStepIndex = null;
      } else {
        return;
      }
    }

    final matched = _indexForShellContext(location, pane);
    if (matched != null && matched != _index) {
      // Web/shell URI often lags after [go] to `/projects/…`; do not rewind an
      // engaged manual tour back to `/` while the user stepped forward.
      if (_engaged && !_isAutoplaying && matched < _index) {
        return;
      }
      _index = matched;
      notifyListeners();
    }
  }

  static String _locationKeyFromShell({
    required Uri uri,
    required StudioOverlayMode overlay,
    required int? projectNumericId,
    required String? stepSlug,
    required ProductWorkspacePane pane,
  }) {
    final projectId = projectNumericId ?? kDemoProjectNumericId;
    final segments = uri.pathSegments;
    if (segments.length >= 3 && segments.first == 'projects') {
      final slug = segments[2];
      if (slug == 'review-pack') {
        return '/projects/$projectId/review-pack';
      }
      if (slug == StudioStep.storyboard.slug &&
          pane == ProductWorkspacePane.productionWorkspace) {
        return studioUriForUtilityPane(ProductWorkspacePane.productionWorkspace);
      }
      if (slug == StudioStep.script.slug &&
          pane == ProductWorkspacePane.scriptWorkspace) {
        return studioUriForUtilityPane(ProductWorkspacePane.scriptWorkspace);
      }
      final step = StudioStep.fromSlug(slug);
      return projectStudioStepUri(
        projectId,
        step,
        storyboardScriptNumericId: step == StudioStep.storyboard
            ? kDemoStoryboardScriptNumericId
            : null,
      ).toString();
    }
    if (overlay == StudioOverlayMode.reviewPack) {
      return '/projects/$projectId/review-pack';
    }
    if (overlay == StudioOverlayMode.projectStudio) {
      final step = StudioStep.fromSlug(stepSlug);
      return projectStudioStepUri(
        projectId,
        step,
        storyboardScriptNumericId: step == StudioStep.storyboard
            ? kDemoStoryboardScriptNumericId
            : null,
      ).toString();
    }
    if (studioUriIsShellHome(uri)) {
      final paneParam = uri.queryParameters[kStudioPaneQueryKey]?.trim();
      if ((uri.path == '/' || uri.path.isEmpty) &&
          (paneParam == null || paneParam.isEmpty) &&
          pane == ProductWorkspacePane.projects) {
        return '/';
      }
      return studioUriForUtilityPane(pane);
    }
    return uri.toString();
  }

  int? _indexForLocation(String location) {
    return _indexForShellContext(location, ProductWorkspacePane.projects);
  }

  int? _indexForShellContext(String location, ProductWorkspacePane pane) {
    final target = Uri.parse(location);
    final matches = <int>[];
    for (var i = 0; i < _stops.length; i++) {
      if (_locationsEquivalent(target, Uri.parse(_stops[i].location))) {
        matches.add(i);
      }
    }
    if (matches.isEmpty) {
      return null;
    }
    if (_engaged) {
      if (matches.contains(_index)) {
        return _index;
      }
      final lock = _lockedStepIndex;
      if (lock != null && matches.contains(lock)) {
        return lock;
      }
    }
    if (matches.length == 1) {
      return matches.single;
    }
    final byPane = matches
        .where((i) => _stopMatchesWorkspacePane(_stops[i], pane))
        .toList();
    if (byPane.isNotEmpty) {
      return byPane.first;
    }
    return matches.first;
  }

  static bool _stopMatchesWorkspacePane(
    ProductDemoTourStop stop,
    ProductWorkspacePane pane,
  ) {
    final loc = Uri.parse(stop.location);
    final wire = loc.queryParameters[kStudioPaneQueryKey]?.trim();
    if (wire != null && wire.isNotEmpty) {
      return studioPaneFromUri(loc) == pane;
    }
    if (pane == ProductWorkspacePane.projects &&
        loc.pathSegments.length >= 3 &&
        loc.pathSegments.first == 'projects') {
      return true;
    }
    return false;
  }

  static bool _locationsEquivalent(Uri a, Uri b) {
    if (a.path == b.path && a.query == b.query) {
      return true;
    }
    if (_isProjectsHome(a) && _isProjectsHome(b)) {
      return true;
    }
    if (a.path.startsWith('/projects/') && b.path.startsWith('/projects/')) {
      final aParts = a.pathSegments;
      final bParts = b.pathSegments;
      if (aParts.length >= 3 &&
          bParts.length >= 3 &&
          aParts[0] == 'projects' &&
          bParts[0] == 'projects' &&
          aParts[1] == bParts[1]) {
        if (aParts[2] == 'review-pack' && bParts[2] == 'review-pack') {
          return true;
        }
        if (aParts[2] != 'review-pack' &&
            bParts[2] != 'review-pack' &&
            aParts[2] == bParts[2]) {
          return true;
        }
      }
    }
    final aPane = a.queryParameters[kStudioPaneQueryKey];
    final bPane = b.queryParameters[kStudioPaneQueryKey];
    if (aPane != null && aPane == bPane && a.path == b.path) {
      return true;
    }
    return false;
  }

  static bool _isProjectsHome(Uri uri) {
    return (uri.path == '/' || uri.path.isEmpty) &&
        (uri.queryParameters[kStudioPaneQueryKey]?.trim().isEmpty ?? true);
  }

  /// Home (or bare shell) while [lockIndex] targets a deeper route — router lag.
  bool _isStaleUriWhileNavigatingForward(Uri uri, int lockIndex) {
    if (lockIndex <= 0) {
      return false;
    }
    final lockedLocation = Uri.parse(_stops[lockIndex].location);
    if (_isProjectsHome(uri) && lockedLocation.path.startsWith('/projects/')) {
      return true;
    }
    if (_isProjectsHome(uri) &&
        lockedLocation.queryParameters.containsKey(kStudioPaneQueryKey)) {
      return true;
    }
    return false;
  }

  void _armManualNavigationCooldown() {
    _suppressSyncUntil = DateTime.now().add(
      Duration(seconds: kIsWeb ? 4 : 2),
    );
  }

  Future<void> _enqueueManualStep(Future<void> Function() action) {
    final run = _manualStepChain == null
        ? action()
        : _manualStepChain!.then((_) => action());
    _manualStepChain = run.catchError((_) {});
    return run;
  }

  Future<void> goToPrevious() {
    return _enqueueManualStep(_goToPreviousNow);
  }

  Future<void> _goToPreviousNow() async {
    if (_stops.isEmpty) {
      return;
    }
    if (_index <= 0) {
      return;
    }
    stopAutoplay();
    final next = _index - 1;
    _index = next;
    _lockedStepIndex = next;
    _armManualNavigationCooldown();
    notifyListeners();
    await _goToIndex(next);
  }

  Future<void> goToNext() {
    return _enqueueManualStep(_goToNextNow);
  }

  Future<void> _goToNextNow() async {
    if (_stops.isEmpty) {
      return;
    }
    if (_index + 1 >= _stops.length) {
      return;
    }
    stopAutoplay();
    final next = _index + 1;
    _index = next;
    _lockedStepIndex = next;
    _armManualNavigationCooldown();
    notifyListeners();
    await _goToIndex(next);
  }

  void startAutoplay({String? languageCode, GoRouter? router}) {
    if (!ProductDemoMode.instance.isActive) {
      return;
    }
    if (_isAutoplaying) {
      if (_autoplayPaused) {
        resumeAutoplay();
      }
      return;
    }
    if (router != null) {
      configure(router);
    }
    if (_router == null) {
      assert(() {
        debugPrint(
          'ProductDemoTour.startAutoplay: GoRouter not configured; '
          'pass router from overlay or call configure() first.',
        );
        return true;
      }());
      return;
    }
    if (languageCode != null) {
      _languageCode = languageCode;
    }
    if (!_engaged) {
      _engaged = true;
      if (_stops.isEmpty) {
        _stops = buildDefaultStops();
      }
    }
    _isAutoplaying = true;
    _autoplayPaused = false;
    _autoplayGeneration++;
    final generation = _autoplayGeneration;
    notifyListeners();
    unawaited(_runAutoplayLoop(generation));
  }

  void pauseAutoplay() {
    if (!_isAutoplaying || _autoplayPaused) {
      return;
    }
    _autoplayPaused = true;
    _autoplayGeneration++;
    notifyListeners();
  }

  void resumeAutoplay() {
    if (!_isAutoplaying || !_autoplayPaused) {
      return;
    }
    _autoplayPaused = false;
    _autoplayGeneration++;
    final generation = _autoplayGeneration;
    notifyListeners();
    unawaited(_runAutoplayLoop(generation));
  }

  void toggleAutoplayPaused() {
    if (_autoplayPaused) {
      resumeAutoplay();
    } else {
      pauseAutoplay();
    }
  }

  void stopAutoplay() {
    _autoplayGeneration++;
    _isAutoplaying = false;
    _autoplayPaused = false;
    notifyListeners();
  }

  /// Legacy alias: starts timed auto-tour from step 0.
  void start({List<ProductDemoTourStop>? stops, String languageCode = 'zh'}) {
    if (stops != null) {
      _stops = stops;
    }
    _languageCode = languageCode;
    _index = 0;
    startAutoplay(languageCode: languageCode);
  }

  void stop() {
    stopAutoplay();
    _engaged = false;
    _lockedStepIndex = null;
    _index = 0;
    notifyListeners();
  }

  void togglePaused() => toggleAutoplayPaused();

  Future<void> _goToIndex(int index) async {
    if (_router == null || _stops.isEmpty) {
      return;
    }
    final epoch = ++_navigationEpoch;
    final target = index.clamp(0, _stops.length - 1);
    _index = target;
    _lockedStepIndex = target;
    notifyListeners();
    try {
      if (epoch != _navigationEpoch) {
        return;
      }
      final nextLocation = _stops[target].location;
      final skipNavigate = target > 0 &&
          _locationsEquivalent(
            Uri.parse(nextLocation),
            Uri.parse(_stops[target - 1].location),
          );
      if (!skipNavigate) {
        await _navigateToLocation(nextLocation);
      }
      if (epoch != _navigationEpoch) {
        final winner = _index.clamp(0, _stops.length - 1);
        if (winner != target) {
          unawaited(_goToIndex(winner));
        }
        return;
      }
    } catch (e, st) {
      if (epoch == _navigationEpoch) {
        _lockedStepIndex = null;
      }
      assert(() {
        debugPrint('ProductDemoTour navigation failed: $e\n$st');
        return true;
      }());
      return;
    }
    _scheduleUnlockFallback(target);
    _scheduleRemeasure();
  }

  Future<void> _navigateToLocation(String location) async {
    final navigate = _navigateStop;
    if (navigate != null) {
      await navigate(location);
      return;
    }
    final router = _router;
    if (router == null) {
      return;
    }
    router.go(location);
  }

  bool _routerMatchesStop(int stopIndex) {
    final router = _router;
    if (router == null || stopIndex < 0 || stopIndex >= _stops.length) {
      return false;
    }
    Uri actual;
    try {
      actual = effectiveRouteUri(router.state.uri);
    } catch (_) {
      return stopIndex == 0;
    }
    final expected = Uri.parse(_stops[stopIndex].location);
    return _locationsEquivalent(actual, expected);
  }

  void _scheduleUnlockFallback(int targetIndex) {
    final delay = kIsWeb ? const Duration(seconds: 5) : const Duration(seconds: 2);
    Future<void>.delayed(delay, () {
      if (_lockedStepIndex != targetIndex) {
        return;
      }
      if (_routerMatchesStop(targetIndex)) {
        _lockedStepIndex = null;
        notifyListeners();
        return;
      }
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (_lockedStepIndex != targetIndex) {
          return;
        }
        if (_routerMatchesStop(targetIndex)) {
          _lockedStepIndex = null;
          notifyListeners();
        }
      });
    });
  }

  void _scheduleRemeasure() {
    ProductDemoTourAnchors.instance.scheduleRemeasure(() {
      notifyListeners();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProductDemoTourAnchors.instance.scheduleRemeasure(() {
        notifyListeners();
      });
    });
  }

  Future<void> _runAutoplayLoop(int generation) async {
    while (_isAutoplaying &&
        !_autoplayPaused &&
        generation == _autoplayGeneration &&
        _router != null &&
        _stops.isNotEmpty) {
      final stopIndex = _index.clamp(0, _stops.length - 1);
      final stop = _stops[stopIndex];
      _lockedStepIndex = stopIndex;
      notifyListeners();
      try {
        final skipNavigate = stopIndex > 0 &&
            _locationsEquivalent(
              Uri.parse(stop.location),
              Uri.parse(_stops[stopIndex - 1].location),
            );
        if (!skipNavigate) {
          await _navigateToLocation(stop.location);
        }
      } catch (e, st) {
        _lockedStepIndex = null;
        assert(() {
          debugPrint('ProductDemoTour navigation failed: $e\n$st');
          return true;
        }());
      }
      _scheduleRemeasure();
      await Future<void>.delayed(const Duration(milliseconds: 280));
      await Future<void>.delayed(stop.dwell);
      if (!_isAutoplaying ||
          _autoplayPaused ||
          generation != _autoplayGeneration) {
        return;
      }
      _lockedStepIndex = null;
      final nextIndex = stopIndex + 1;
      if (nextIndex >= _stops.length) {
        _isAutoplaying = false;
        notifyListeners();
        return;
      }
      _index = nextIndex;
      notifyListeners();
    }
    if (generation == _autoplayGeneration) {
      _isAutoplaying = false;
      _lockedStepIndex = null;
      notifyListeners();
    }
  }

  @visibleForTesting
  int? get lockedStepIndexForTest => _lockedStepIndex;

  @visibleForTesting
  bool get debugHasNavigateStop => _navigateStop != null;

  @visibleForTesting
  void debugPrimeTourStep({
    required int index,
    int? lockedStepIndex,
  }) {
    _engaged = true;
    _stops = buildDefaultStops();
    _index = index.clamp(0, _stops.length - 1);
    _lockedStepIndex = lockedStepIndex;
  }
}
