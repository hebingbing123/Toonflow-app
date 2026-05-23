import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';

/// Router-backed MaterialApp for overlay / chrome widget tests.
Widget productShellOverlayTestApp(
  GoRouter router, {
  Size size = const Size(1600, 1000),
  Locale locale = const Locale('en'),
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, widget) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: widget ?? const SizedBox.shrink(),
      ),
      routerConfig: router,
    ),
  );
}

HomePage productShellOverlayHomePage({
  required StudioOverlayMode overlay,
  required int projectNumericId,
  int? scriptNumericId,
  String? stepSlug,
}) {
  final projectUuid =
      '00000000-0000-0000-0000-${projectNumericId.toString().padLeft(12, '0')}';
  return HomePage(
    shellMode: HomeShellMode.product,
    studioOverlay: overlay,
    studioProjectNumericId: projectNumericId,
    studioScriptNumericId: scriptNumericId,
    studioStepSlug: stepSlug,
    debugAuthenticatedAccessToken: 'test-token',
    debugSkipSessionContextSync: true,
    debugSkipAuthListenerAttach: true,
    debugStudioProjectUuid: projectUuid,
    debugStudioProjectName: 'Project Delta',
    debugProjectStudioSnapshotLoader: (accessToken, projectUuid) async =>
        const StudioReadinessSnapshot(completedSteps: 4),
  );
}

GoRouter productShellStoryboardOverlayRouter({int projectNumericId = 7}) {
  return GoRouter(
    initialLocation: '/projects/$projectNumericId/storyboard-studio',
    routes: <RouteBase>[
      GoRoute(
        path: '/projects/:projectNumericId/storyboard-studio',
        builder: (context, state) => productShellOverlayHomePage(
          overlay: StudioOverlayMode.storyboardStudio,
          projectNumericId: int.parse(
            state.pathParameters['projectNumericId']!,
          ),
        ),
      ),
    ],
  );
}
