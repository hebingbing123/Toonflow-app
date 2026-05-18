import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/project_studio_page.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _routerApp(GoRouter router) {
  return MaterialApp.router(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  testWidgets('project studio step chips and episode console action navigate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'script',
    });

    late GoRouter router;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: 'project-42',
      projectName: 'Project Delta',
      accessToken: null,
      initialStep: StudioStep.script,
      onExit: () {},
      onStepChanged: (_) {},
      onOpenAgentDrawer: () {},
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    router = GoRouter(
      initialLocation: '/projects/42/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/42/script',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
        GoRoute(
          path: '/projects/42/art',
          builder: (context, state) => const Scaffold(body: Text('route-art')),
        ),
        GoRoute(
          path: '/projects/42/console/1',
          builder: (context, state) =>
              const Scaffold(body: Text('route-console')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('body-script'), findsOneWidget);

    await tester.tap(find.text('2. Art'));
    await tester.pumpAndSettle();
    expect(find.text('route-art'), findsOneWidget);

    router.go('/projects/42/script');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Episode console'));
    await tester.pumpAndSettle();
    expect(find.text('route-console'), findsOneWidget);
  });
}
