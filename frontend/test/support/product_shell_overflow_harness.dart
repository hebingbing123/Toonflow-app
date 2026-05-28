import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/components/openflow_brand.dart';
import 'package:openflow_app/debug/product_shell_debug_preview.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/product_shell/studio_shell_branches.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:openflow_app/shell/studio_settings_hub_navigation.dart';

import 'ignore_layout_overflow.dart';
import 'product_shell_overlay_harness.dart';

HomePage _debugProductShellHomePage({
  Key? key,
  ProductWorkspacePane? initialProductPane,
  StatefulNavigationShell? navigationShell,
  StudioOverlayMode studioOverlay = StudioOverlayMode.none,
  int? studioProjectNumericId,
  String? studioStepSlug,
  int? studioScriptNumericId,
  ProductShellDebugPreviewData? debugPreviewData,
}) {
  final preview = debugPreviewData;
  final projectNumericId =
      studioProjectNumericId ?? preview?.productScopedProjectNumericId ?? 7;
  final projectUuid =
      '00000000-0000-0000-0000-${projectNumericId.toString().padLeft(12, '0')}';
  return HomePage(
    key: key,
    shellMode: HomeShellMode.product,
    initialProductPane: initialProductPane,
    navigationShell: navigationShell,
    studioOverlay: studioOverlay,
    studioProjectNumericId: studioProjectNumericId ?? projectNumericId,
    studioStepSlug: studioStepSlug,
    studioScriptNumericId: studioScriptNumericId,
    debugAuthenticatedAccessToken: 'test-token',
    debugSkipSessionContextSync: true,
    debugSkipAuthListenerAttach: true,
    debugStudioProjectUuid: projectUuid,
    debugStudioProjectName: '春季短剧 · E2E 预览',
    debugPreviewData: preview,
    debugProjectStudioSnapshotLoader:
        preview?.studioSnapshotLoader ??
        (_, _) async => const StudioReadinessSnapshot(completedSteps: 4),
    debugHelpHubWebhooks: preview?.helpHubWebhooks,
    debugHelpHubLatestCreatedWebhook: preview?.helpHubLatestCreatedWebhook,
    debugHelpHubBillingEventsPage: preview?.helpHubBillingEventsPage,
    debugHelpHubWebhookDeliveries: preview?.helpHubWebhookDeliveries,
    debugHelpHubWebhookLastTestResults: preview?.helpHubWebhookLastTestResults,
  );
}

Page<void> _placeholderPage(GoRouterState state) {
  return const NoTransitionPage<void>(child: SizedBox.shrink());
}

/// Full product router with debug auth — mirrors [createStudioRouter] for widget tests.
GoRouter createProductShellDebugRouter({
  ProductShellDebugPreviewData? debugPreviewData,
}) {
  final preview = debugPreviewData;
  return GoRouter(
    initialLocation: '/',
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
          return _debugProductShellHomePage(
            key: const ValueKey<String>('studio-shell-root'),
            navigationShell: navigationShell,
            debugPreviewData: preview,
          );
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => _placeholderPage(state),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings/models',
        builder: (context, state) => _debugProductShellHomePage(
          key: const ValueKey<String>('studio-shell-model-settings'),
          initialProductPane: ProductWorkspacePane.platformConfig,
          debugPreviewData: preview,
        ),
      ),
      GoRoute(
        path: '/projects/:projectNumericId/review-pack',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['projectNumericId']!);
          return _debugProductShellHomePage(
            key: ValueKey<String>('review-pack-$id'),
            studioOverlay: StudioOverlayMode.reviewPack,
            studioProjectNumericId: id,
            debugPreviewData: preview,
          );
        },
      ),
      GoRoute(
        path: '/projects/:projectNumericId/storyboard-studio',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['projectNumericId']!);
          return _debugProductShellHomePage(
            key: ValueKey<String>('storyboard-$id'),
            studioOverlay: StudioOverlayMode.storyboardStudio,
            studioProjectNumericId: id,
            debugPreviewData: preview,
          );
        },
      ),
      GoRoute(
        path: '/projects/:projectNumericId/console/:scriptNumericId',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['projectNumericId']!);
          final scriptId = int.parse(state.pathParameters['scriptNumericId']!);
          return _debugProductShellHomePage(
            key: ValueKey<String>('console-$id-$scriptId'),
            studioOverlay: StudioOverlayMode.episodeConsole,
            studioProjectNumericId: id,
            studioScriptNumericId: scriptId,
            debugPreviewData: preview,
          );
        },
      ),
      GoRoute(
        path: '/projects/:projectNumericId/:stepSlug',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['projectNumericId']!);
          return _debugProductShellHomePage(
            key: ValueKey<String>('project-$id-${state.pathParameters['stepSlug']}'),
            initialProductPane: ProductWorkspacePane.projects,
            studioOverlay: StudioOverlayMode.projectStudio,
            studioProjectNumericId: id,
            studioStepSlug: state.pathParameters['stepSlug'],
            debugPreviewData: preview,
          );
        },
      ),
    ],
  );
}

/// Navigation helpers for route / overlay overflow widget tests (no PNG capture).
class ProductShellOverflowHarness {
  ProductShellOverflowHarness(this.tester, this.router);

  final WidgetTester tester;
  final GoRouter router;

  Future<void> bootstrap({
    required Size size,
    String location = '/',
    Locale locale = const Locale('zh'),
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      productShellOverlayTestApp(router, size: size, locale: locale),
    );
    router.go(location);
    await pumpFrames(count: 24);
  }

  Future<void> pumpFrames({int count = 12}) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      takeBenignLayoutOverflowExceptions(tester);
    }
  }

  Future<void> goLocation(String location) async {
    router.go(location);
    await pumpFrames(count: 24);
  }

  Future<void> goPane(ProductWorkspacePane pane) {
    return goLocation(studioUriForUtilityPane(pane));
  }

  Future<void> goProjectsHome() => goLocation('/');

  Future<void> openMoreMenu() async {
    final moreZh = find.byTooltip('更多');
    final moreEn = find.byTooltip('More');
    if (moreZh.evaluate().isNotEmpty) {
      await tester.tap(moreZh.first, warnIfMissed: false);
    } else if (moreEn.evaluate().isNotEmpty) {
      await tester.tap(moreEn.first, warnIfMissed: false);
    } else {
      final apps = find.byIcon(Icons.apps_outlined);
      if (apps.evaluate().isNotEmpty) {
        await tester.tap(apps.last, warnIfMissed: false);
      }
    }
    await pumpFrames(count: 16);
  }

  Future<void> openCreateProjectWizard() async {
    await goProjectsHome();
    final create = find.text('新建项目');
    final createEn = find.text('New project');
    final target = create.evaluate().isNotEmpty ? create : createEn;
    expect(target, findsWidgets);
    await tester.tap(target.last, warnIfMissed: false);
    await pumpFrames(count: 16);
    final titleZh = find.text('创建项目');
    final titleEn = find.text('Create project');
    expect(
      titleZh.evaluate().isNotEmpty || titleEn.evaluate().isNotEmpty,
      isTrue,
    );
  }

  Future<void> openSettingsHub() async {
    await goPane(ProductWorkspacePane.account);
    await pumpFrames(count: 24);
  }

  Future<void> openSettingsTab(int index) async {
    StudioSettingsHubNavigation.requestTab(index.clamp(0, 3));
    await openSettingsHub();
    await pumpFrames(count: 16);
  }

  Future<bool> tryTapFirstLabel(List<String> labels) async {
    for (final label in labels) {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        continue;
      }
      await tester.tap(finder.first, warnIfMissed: false);
      await pumpFrames(count: 16);
      return true;
    }
    return false;
  }

  Future<bool> tryToggleCollapsibleFilter() async {
    final panel = find.byKey(const Key('studio_collapsible_filter_panel'));
    if (panel.evaluate().isEmpty) {
      return false;
    }
    await tester.tap(panel.first, warnIfMissed: false);
    await pumpFrames(count: 16);
    return true;
  }

  Future<void> closeOverlay() async {
    if (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first, warnIfMissed: false);
      await pumpFrames();
      return;
    }
    if (find.byIcon(Icons.close).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.close).first, warnIfMissed: false);
      await pumpFrames();
      return;
    }
    if (find.byType(ModalBarrier).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(12, 12));
      await pumpFrames();
    }
  }

  Future<void> dismissToProjectsHome() async {
    await closeOverlay();
    if (find.text('新建项目').evaluate().isEmpty &&
        find.text('你的项目').evaluate().isEmpty &&
        find.text('New project').evaluate().isEmpty) {
      final brand = find.byType(OpenFlowBrandMark);
      if (brand.evaluate().isNotEmpty) {
        await tester.tap(brand.first, warnIfMissed: false);
        await pumpFrames(count: 16);
      }
      await goProjectsHome();
    }
  }

  Future<bool> openTaskWorkbench() async {
    await goPane(ProductWorkspacePane.tasks);
    return tryTapFirstLabel(<String>['打开任务工作台', 'Open task workbench']);
  }

  Future<bool> openQualityWorkbench() async {
    await goPane(ProductWorkspacePane.quality);
    return tryTapFirstLabel(<String>['打开质量工作台', 'Open quality workbench']);
  }

  Future<bool> openScriptSetupSheet() async {
    await goLocation('/projects/7/script');
    await pumpFrames(count: 24);
    return tryTapFirstLabel(<String>[
      '导入小说',
      'Import novel',
      '新建剧本',
      'New script',
    ]);
  }
}
