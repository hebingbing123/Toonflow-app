import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/project_studio_page.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

void main() {
  testWidgets('legacy /quality route shows deliver quality tab body', (
    WidgetTester tester,
  ) async {
    late GoRouter router;
    final host = ProjectStudioHost(
      projectNumericId: 9,
      projectUuid: '00000000-0000-0000-0000-000000000009',
      projectName: 'Quality Test',
      accessToken: null,
      initialStep: StudioStep.quality,
      onExit: () {},
      onStepChanged: (_) {},
      onOpenAgentDrawer: () {},
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    router = GoRouter(
      initialLocation: '/projects/9/quality',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
        GoRoute(
          path: '/projects/:projectNumericId/deliver',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('body-quality'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      contains('tab=quality'),
    );
  });
}
