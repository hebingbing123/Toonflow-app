import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../design_system/studio_page_transitions.dart';
import '../global_search/search_results_page.dart';
import '../home_page.dart';
import '../project_studio/studio_overlay_mode.dart';
import '../project_studio/studio_step.dart';
import '../shell/home_shell_mode.dart';
import '../shell/navigation_controller.dart';
import '../status_page.dart';
import 'studio_route_guards.dart';
import 'studio_shell_branches.dart';

Page<void> _studioShellPlaceholderPage(GoRouterState state) {
  return const NoTransitionPage<void>(child: SizedBox.shrink());
}

/// Full-screen shot list / grid studio (not the six-step SOP route).
String studioStoryboardStudioRoute(int projectNumericId) =>
    '/projects/$projectNumericId/storyboard-studio';

HomePage buildStoryboardStudioHomePage({required int projectNumericId}) {
  return HomePage(
    key: ValueKey<String>('storyboard-$projectNumericId'),
    shellMode: HomeShellMode.product,
    studioOverlay: StudioOverlayMode.storyboardStudio,
    studioProjectNumericId: projectNumericId,
  );
}

HomePage buildEpisodeConsoleHomePage({
  required int projectNumericId,
  required int scriptNumericId,
}) {
  return HomePage(
    key: ValueKey<String>('console-$projectNumericId-$scriptNumericId'),
    shellMode: HomeShellMode.product,
    studioOverlay: StudioOverlayMode.episodeConsole,
    studioProjectNumericId: projectNumericId,
    studioScriptNumericId: scriptNumericId,
  );
}

HomePage buildProjectStudioHomePage({
  required int projectNumericId,
  required String? stepSlug,
}) {
  return HomePage(
    key: ValueKey<String>('project-$projectNumericId-${stepSlug ?? ''}'),
    shellMode: HomeShellMode.product,
    initialProductPane: ProductWorkspacePane.projects,
    studioOverlay: StudioOverlayMode.projectStudio,
    studioProjectNumericId: projectNumericId,
    studioStepSlug: stepSlug,
  );
}

HomePage buildReviewPackHomePage({required int projectNumericId}) {
  return HomePage(
    key: ValueKey<String>('review-pack-$projectNumericId'),
    shellMode: HomeShellMode.product,
    initialProductPane: ProductWorkspacePane.projects,
    studioOverlay: StudioOverlayMode.reviewPack,
    studioProjectNumericId: projectNumericId,
  );
}

String studioProjectRootRedirectLocation(String projectNumericId) {
  return '/projects/$projectNumericId/${StudioStep.script.slug}';
}

/// Studio product routes.
GoRouter createStudioRouter() {
  final validStepSlugs = StudioStep.values.map((s) => s.slug).toSet();
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => StudioNotFoundPage(key: state.pageKey),
    routes: <RouteBase>[
      GoRoute(
        path: '/notifications',
        redirect: (context, state) =>
            studioUriForUtilityPane(ProductWorkspacePane.notifications),
      ),
      GoRoute(
        path: '/settings',
        redirect: (context, state) =>
            studioUriForUtilityPane(ProductWorkspacePane.account),
      ),
      GoRoute(
        path: '/help',
        redirect: (context, state) =>
            studioUriForUtilityPane(ProductWorkspacePane.helpHub),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomePage(
            key: const ValueKey<String>('studio-shell-root'),
            shellMode: HomeShellMode.product,
            navigationShell: navigationShell,
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                pageBuilder: (context, state) =>
                    _studioShellPlaceholderPage(state),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings/models',
        builder: (context, state) => const HomePage(
          key: ValueKey<String>('studio-shell-model-settings'),
          shellMode: HomeShellMode.product,
          initialProductPane: ProductWorkspacePane.platformConfig,
        ),
      ),
      GoRoute(
        path: '/projects/:projectNumericId/storyboard-studio',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['projectNumericId']!);
          return buildStoryboardStudioHomePage(projectNumericId: id);
        },
      ),
      GoRoute(
        path: '/projects/:projectNumericId/console/:scriptNumericId',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['projectNumericId']!);
          final scriptId = int.parse(state.pathParameters['scriptNumericId']!);
          return buildEpisodeConsoleHomePage(
            projectNumericId: id,
            scriptNumericId: scriptId,
          );
        },
      ),
      GoRoute(
        path: '/projects/:projectNumericId/review-pack',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['projectNumericId']!);
          return buildReviewPackHomePage(projectNumericId: id);
        },
      ),
      GoRoute(
        path: '/projects/:projectNumericId',
        redirect: (context, state) {
          final id = state.pathParameters['projectNumericId'];
          return studioProjectRootRedirectLocation(id!);
        },
      ),
      GoRoute(
        path: '/projects/:projectNumericId/:stepSlug',
        redirect: (context, state) =>
            studioProjectStepRedirect(state, validSlugs: validStepSlugs),
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['projectNumericId']!);
          return studioProjectStudioTransitionPage(
            key: state.pageKey,
            child: buildProjectStudioHomePage(
              projectNumericId: id,
              stepSlug: state.pathParameters['stepSlug'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters['q'] ?? '';
          final accessToken = kSupabaseConfigured
              ? Supabase.instance.client.auth.currentSession?.accessToken
              : null;
          return studioFadeTransitionPage(
            key: state.pageKey,
            child: SearchResultsPage(query: query, accessToken: accessToken),
          );
        },
      ),
      GoRoute(
        path: '/status',
        pageBuilder: (context, state) => studioFadeTransitionPage(
          key: state.pageKey,
          child: StatusPage(),
        ),
      ),
    ],
  );
}
