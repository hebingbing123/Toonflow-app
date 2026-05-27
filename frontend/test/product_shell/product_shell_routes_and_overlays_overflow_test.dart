import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/auth/controller.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/login_page.dart';
import 'package:openflow_app/product_shell/studio_shell_branches.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

import '../support/layout_overflow_expectations.dart';
import '../support/product_shell_overflow_harness.dart';
import '../support/product_shell_preview_fixtures.dart';

/// Widths aligned with E2E audit + layout breakpoint gates.
const _auditWidths = <double>[375, 960, 1920];

/// Utility / workflow panes captured by ui-ux-audit E2E route gallery.
const _auditUtilityPanes = <ProductWorkspacePane>[
  ProductWorkspacePane.projects,
  ProductWorkspacePane.notifications,
  ProductWorkspacePane.account,
  ProductWorkspacePane.tasks,
  ProductWorkspacePane.quality,
  ProductWorkspacePane.jobs,
  ProductWorkspacePane.shortVideoSpace,
  ProductWorkspacePane.teamWorkspaces,
  ProductWorkspacePane.apiKeys,
  ProductWorkspacePane.contentCompliance,
  ProductWorkspacePane.platformStatus,
  ProductWorkspacePane.platformConfig,
  ProductWorkspacePane.scriptWorkspace,
  ProductWorkspacePane.productionWorkspace,
  ProductWorkspacePane.helpHub,
  ProductWorkspacePane.workspaceActivity,
  ProductWorkspacePane.benchmark,
];

/// Project studio six-step SOP + quality tab.
final _auditProjectStudioSteps = <({String id, String location})>[
  for (final step in StudioStep.sopSteps)
    (id: 'project_studio_${step.slug}', location: '/projects/7/${step.slug}'),
  (id: 'project_studio_quality', location: '/projects/7/quality'),
];

/// Deep studio routes (overlay modes).
const _auditStudioRoutes = <({String id, String location})>[
  (id: 'storyboard_studio', location: '/projects/7/storyboard-studio'),
  (id: 'episode_console', location: '/projects/7/console/3'),
  (id: 'review_pack', location: '/projects/7/review-pack'),
  (id: 'platform_config_models', location: '/settings/models'),
];

GoRouter _createPreviewRouter() {
  return createProductShellDebugRouter(
    debugPreviewData: buildProductShellOverflowPreviewData(),
  );
}

AuthController _loginAuthController() {
  return AuthController(
    onErrorChanged: (_) {},
    onSignedOut: () async {},
    l10nProvider: () => null,
  );
}

Widget _loginTestApp(Size size) {
  final authController = _loginAuthController();
  return MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: true),
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, child) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: child ?? const SizedBox.shrink(),
      ),
      home: ProductLoginPage(
        authController: authController,
        onSignIn: () {},
        onSignUp: () {},
      ),
    ),
  );
}

void main() {
  group('login page — no layout overflow', () {
    for (final width in _auditWidths) {
      testWidgets('@ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(_loginTestApp(Size(width, 900)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expectNoLayoutOverflow(tester);
      });
    }
  });

  group('utility panes — no layout overflow (mock preview)', () {
    for (final pane in _auditUtilityPanes) {
      for (final width in _auditWidths) {
        testWidgets('${pane.name} @ ${width.round()}px', (tester) async {
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final router = _createPreviewRouter();
          addTearDown(router.dispose);
          final harness = ProductShellOverflowHarness(tester, router);
          await harness.bootstrap(
            size: Size(width, 900),
            location: studioUriForUtilityPane(pane),
          );
          expectNoLayoutOverflow(tester);
        });
      }
    }
  });

  group('project studio steps — no layout overflow (mock preview)', () {
    for (final route in _auditProjectStudioSteps) {
      for (final width in _auditWidths) {
        testWidgets('${route.id} @ ${width.round()}px', (tester) async {
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final router = _createPreviewRouter();
          addTearDown(router.dispose);
          final harness = ProductShellOverflowHarness(tester, router);
          await harness.bootstrap(
            size: Size(width, 900),
            location: route.location,
          );
          expectNoLayoutOverflow(tester);
        });
      }
    }
  });

  group('studio overlay routes — no layout overflow (mock preview)', () {
    for (final route in _auditStudioRoutes) {
      for (final width in _auditWidths) {
        testWidgets('${route.id} @ ${width.round()}px', (tester) async {
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final router = _createPreviewRouter();
          addTearDown(router.dispose);
          final harness = ProductShellOverflowHarness(tester, router);
          await harness.bootstrap(
            size: Size(width, 900),
            location: route.location,
          );
          expectNoLayoutOverflow(tester);
        });
      }
    }
  });

  group('overlays & dialogs — no layout overflow (mock preview)', () {
    for (final width in _auditWidths) {
      testWidgets('more menu @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(size: Size(width, 900));
        await harness.openMoreMenu();
        expectNoLayoutOverflow(tester);
        await harness.dismissToProjectsHome();
      });

      testWidgets('create project wizard @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(size: Size(width, 900));
        await harness.openCreateProjectWizard();
        expectNoLayoutOverflow(tester);
        await harness.dismissToProjectsHome();
      });

      testWidgets('settings plan tab @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(size: Size(width, 900));
        await harness.openSettingsTab(1);
        expectNoLayoutOverflow(tester);
      });

      testWidgets('settings api tab @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(size: Size(width, 900));
        await harness.openSettingsTab(2);
        expectNoLayoutOverflow(tester);
      });

      testWidgets('settings workspaces tab @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(size: Size(width, 900));
        await harness.openSettingsTab(3);
        expectNoLayoutOverflow(tester);
      });

      testWidgets('api keys create dialog @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.apiKeys),
        );
        await harness.tryTapFirstLabel(<String>[
          '创建 API 密钥',
          'Create API key',
          '创建密钥',
        ]);
        expectNoLayoutOverflow(tester);
        await harness.dismissToProjectsHome();
      });

      testWidgets('help hub add webhook @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.helpHub),
        );
        await harness.tryTapFirstLabel(<String>[
          '添加 Webhook',
          'Add webhook',
          '新建 Webhook',
        ]);
        expectNoLayoutOverflow(tester);
        await harness.dismissToProjectsHome();
      });

      testWidgets('platform config vendor dialog @ ${width.round()}px', (
        tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.platformConfig),
        );
        await harness.tryTapFirstLabel(<String>[
          '添加供应商',
          'Add vendor',
          '连接供应商',
        ]);
        expectNoLayoutOverflow(tester);
        await harness.dismissToProjectsHome();
      });

      testWidgets('task center filter panel @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.tasks),
        );
        await harness.tryToggleCollapsibleFilter();
        expectNoLayoutOverflow(tester);
      });

      testWidgets('short video filter @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.shortVideoSpace),
        );
        await harness.tryTapFirstLabel(<String>['筛选', 'Filter', '过滤器']);
        await harness.tryToggleCollapsibleFilter();
        expectNoLayoutOverflow(tester);
      });

      testWidgets('notifications filter @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.notifications),
        );
        await harness.tryTapFirstLabel(<String>['筛选', 'Filter', '通知设置']);
        await harness.tryToggleCollapsibleFilter();
        expectNoLayoutOverflow(tester);
      });

      testWidgets('task workbench @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.tasks),
        );
        await harness.openTaskWorkbench();
        expectNoLayoutOverflow(tester);
        await harness.dismissToProjectsHome();
      });

      testWidgets('quality workbench @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.quality),
        );
        await harness.openQualityWorkbench();
        expectNoLayoutOverflow(tester);
        await harness.dismissToProjectsHome();
      });

      testWidgets('script setup sheet @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = _createPreviewRouter();
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: '/projects/7/script',
        );
        await harness.openScriptSetupSheet();
        expectNoLayoutOverflow(tester);
        await harness.dismissToProjectsHome();
      });
    }
  });
}
