import 'package:go_router/go_router.dart';

import '../product_shell/studio_shell_branches.dart';
import '../project_studio/studio_step.dart';
import '../shell/navigation_controller.dart';
import 'product_demo_tour.dart';

/// Long-lived demo-tour navigation (not tied to a [HomePage] route instance).
///
/// GoRouter mounts a new [HomePage] for `/projects/…`, which disposes the shell
/// instance mid-navigation if [navigateStop] is bound to [State].
class ProductDemoTourShellNavigator {
  ProductDemoTourShellNavigator._();

  static final ProductDemoTourShellNavigator instance =
      ProductDemoTourShellNavigator._();

  GoRouter? _router;
  ShellNavigationController? _shellNavigation;

  void attach({
    required GoRouter router,
    required ShellNavigationController shellNavigation,
  }) {
    _router = router;
    _shellNavigation = shellNavigation;
    ProductDemoTour.instance.configure(
      router,
      navigateStop: navigateToLocation,
    );
  }

  /// Refresh router reference from a mounted [HomePage] without rebinding [navigateStop].
  void updateRouter(GoRouter router) {
    _router = router;
    ProductDemoTour.instance.configure(router);
  }

  ShellNavigationController? get shellNavigation => _shellNavigation;

  GoRouter? get router => _router;

  static ProductWorkspacePane paneForProjectStepSlug(String stepSlug) {
    return switch (StudioStep.fromSlug(stepSlug)) {
      StudioStep.script => ProductWorkspacePane.scriptWorkspace,
      StudioStep.storyboard => ProductWorkspacePane.productionWorkspace,
      _ => ProductWorkspacePane.projects,
    };
  }

  Future<void> navigateToLocation(String location) async {
    final router = _router;
    final shellNav = _shellNavigation;
    if (router == null || shellNav == null) {
      return;
    }
    final uri = Uri.parse(location);
    final segments = uri.pathSegments;
    if (segments.length >= 3 && segments.first == 'projects') {
      final stepSlug = segments[2];
      if (stepSlug != 'review-pack') {
        shellNav.selectProductWorkspacePane(paneForProjectStepSlug(stepSlug));
      }
      router.go(location);
      return;
    }
    if (studioUriIsShellHome(uri)) {
      final pane = studioPaneFromUri(uri);
      if (pane == ProductWorkspacePane.projects &&
          (uri.path == '/' || uri.path.isEmpty) &&
          (uri.queryParameters[kStudioPaneQueryKey]?.trim().isEmpty ?? true)) {
        shellNav.selectProductWorkspacePane(ProductWorkspacePane.projects);
        router.go('/');
        return;
      }
      shellNav.selectProductWorkspacePane(pane);
      if (kStudioPaneUriSyncedPanes.contains(pane)) {
        router.go(studioUriForUtilityPane(pane));
      } else {
        router.go(location);
      }
      return;
    }
    router.go(location);
  }
}
