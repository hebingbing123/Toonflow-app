import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/debug/product_shell_debug_preview.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/project_studio/project_studio_scope.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

import 'product_shell_preview_fixtures.dart';

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
  ProductShellDebugPreviewData? debugPreviewData,
  ProjectStudioReadinessLoader? snapshotLoader,
}) {
  final preview = debugPreviewData ?? buildProductShellOverflowPreviewData();
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
    debugStudioProjectName: '春季短剧 · E2E 预览',
    debugPreviewData: preview,
    debugProjectStudioSnapshotLoader:
        snapshotLoader ??
        preview.studioSnapshotLoader ??
        (_, _) async => const StudioReadinessSnapshot(completedSteps: 4),
    debugHelpHubWebhooks: preview.helpHubWebhooks,
    debugHelpHubLatestCreatedWebhook: preview.helpHubLatestCreatedWebhook,
    debugHelpHubBillingEventsPage: preview.helpHubBillingEventsPage,
    debugHelpHubWebhookDeliveries: preview.helpHubWebhookDeliveries,
    debugHelpHubWebhookLastTestResults: preview.helpHubWebhookLastTestResults,
  );
}

GoRouter productShellStoryboardOverlayRouter({
  int projectNumericId = 7,
  ProductShellDebugPreviewData? debugPreviewData,
}) {
  final preview = debugPreviewData ?? buildProductShellOverflowPreviewData();
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
          debugPreviewData: preview,
        ),
      ),
    ],
  );
}

/// Product shell at `/` with optional initial utility pane (tasks, jobs, …).
GoRouter productShellHomeRouter({
  ProductWorkspacePane? initialPane,
  ProductShellDebugPreviewData? debugPreviewData,
}) {
  final preview = debugPreviewData ?? buildProductShellOverflowPreviewData();
  final projectUuid =
      '00000000-0000-0000-0000-${(preview.productScopedProjectNumericId ?? 7).toString().padLeft(12, '0')}';
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => HomePage(
          shellMode: HomeShellMode.product,
          initialProductPane: initialPane,
          debugAuthenticatedAccessToken: 'test-token',
          debugSkipSessionContextSync: true,
          debugSkipAuthListenerAttach: true,
          debugStudioProjectUuid: projectUuid,
          debugStudioProjectName: '春季短剧 · E2E 预览',
          debugPreviewData: preview,
          debugProjectStudioSnapshotLoader: preview.studioSnapshotLoader,
          debugHelpHubWebhooks: preview.helpHubWebhooks,
          debugHelpHubLatestCreatedWebhook: preview.helpHubLatestCreatedWebhook,
          debugHelpHubBillingEventsPage: preview.helpHubBillingEventsPage,
          debugHelpHubWebhookDeliveries: preview.helpHubWebhookDeliveries,
          debugHelpHubWebhookLastTestResults: preview.helpHubWebhookLastTestResults,
        ),
      ),
    ],
  );
}
