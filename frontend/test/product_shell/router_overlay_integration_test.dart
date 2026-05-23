import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';

import '../support/ignore_layout_overflow.dart';

void _expectNoUnexpectedLayoutExceptions(WidgetTester tester) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    expect(
      exception.toString(),
      anyOf(contains('overflowed'), contains('RenderFlex')),
    );
  }
}

Widget _routerApp(GoRouter router, {Size size = const Size(1600, 1000)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, widget) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: widget ?? const SizedBox(),
      ),
      routerConfig: router,
    ),
  );
}

HomePage _overlayPage({
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

HomePage _shellPage({int? initialProjectNumericId}) {
  return HomePage(
    shellMode: HomeShellMode.product,
    debugAuthenticatedAccessToken: 'test-token',
    debugSkipSessionContextSync: true,
    debugSkipAuthListenerAttach: true,
    studioProjectNumericId: initialProjectNumericId,
  );
}

void main() {
  installLayoutOverflowIgnoreForTests();

  testWidgets('storyboard overlay route renders through GoRouter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/projects/7/storyboard-studio',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/:projectNumericId/storyboard-studio',
          builder: (context, state) => _overlayPage(
            overlay: StudioOverlayMode.storyboardStudio,
            projectNumericId: int.parse(
              state.pathParameters['projectNumericId']!,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('Storyboard studio'), findsOneWidget);
    expect(find.byKey(const Key('product-auth-submit')), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/projects/7/storyboard-studio',
    );
    _expectNoUnexpectedLayoutExceptions(tester);
  });

  testWidgets('storyboard overlay open production enters shell pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/projects/7/storyboard-studio',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => _shellPage()),
        GoRoute(
          path: '/projects/:projectNumericId/storyboard-studio',
          builder: (context, state) => _overlayPage(
            overlay: StudioOverlayMode.storyboardStudio,
            projectNumericId: int.parse(
              state.pathParameters['projectNumericId']!,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Script'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/projects/7/script',
    );
    expect(find.text('Storyboard studio'), findsNothing);
    _expectNoUnexpectedLayoutExceptions(tester);
  });

  testWidgets('storyboard overlay close navigates to script route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/projects/7/storyboard-studio',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/:projectNumericId/storyboard-studio',
          builder: (context, state) => _overlayPage(
            overlay: StudioOverlayMode.storyboardStudio,
            projectNumericId: int.parse(
              state.pathParameters['projectNumericId']!,
            ),
          ),
        ),
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) => _overlayPage(
            overlay: StudioOverlayMode.projectStudio,
            projectNumericId: int.parse(
              state.pathParameters['projectNumericId']!,
            ),
            stepSlug: state.pathParameters['stepSlug'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/projects/7/storyboard',
    );
    expect(find.text('Storyboard studio'), findsNothing);
    expect(find.text('Project Delta'), findsOneWidget);
    _expectNoUnexpectedLayoutExceptions(tester);
  });

  testWidgets('episode console route renders through GoRouter', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2560, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/projects/7/console/3',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/:projectNumericId/console/:scriptNumericId',
          builder: (context, state) => _overlayPage(
            overlay: StudioOverlayMode.episodeConsole,
            projectNumericId: int.parse(
              state.pathParameters['projectNumericId']!,
            ),
            scriptNumericId: int.parse(
              state.pathParameters['scriptNumericId']!,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _routerApp(router, size: const Size(2560, 2000)),
    );
    await pumpIgnoringBenignLayoutOverflow(tester);
    await pumpIgnoringBenignLayoutOverflow(
      tester,
      const Duration(milliseconds: 500),
    );

    expect(find.text('Episode 3'), findsOneWidget);
    expect(find.text('Full studio'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/projects/7/console/3',
    );
  });

  testWidgets('project root redirect lands on project studio route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/projects/7',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/:projectNumericId',
          redirect: (context, state) =>
              '/projects/${state.pathParameters['projectNumericId']!}/script',
        ),
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) => _overlayPage(
            overlay: StudioOverlayMode.projectStudio,
            projectNumericId: int.parse(
              state.pathParameters['projectNumericId']!,
            ),
            stepSlug: state.pathParameters['stepSlug'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('Project Delta'), findsOneWidget);
    expect(find.text('4/6'), findsOneWidget);
    expect(find.byTooltip('Episode console'), findsWidgets);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/projects/7/script',
    );
    _expectNoUnexpectedLayoutExceptions(tester);
  });
}
