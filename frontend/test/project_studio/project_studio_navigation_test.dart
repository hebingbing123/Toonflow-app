import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_editor/style_pack_catalog.dart';
import 'package:openflow_app/project_studio/art_step_panel.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/project_studio_page.dart';
import 'package:openflow_app/project_studio/project_studio_navigation.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/rust_api.dart';
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
  group('projectStudioStepUri', () {
    test('quality maps to deliver with tab=quality', () {
      final uri = projectStudioStepUri(9, StudioStep.quality);
      expect(uri.path, '/projects/9/deliver');
      expect(uri.queryParameters['tab'], 'quality');
    });

    test('storyboard uses slug path', () {
      final uri = projectStudioStepUri(9, StudioStep.storyboard);
      expect(uri.path, '/projects/9/storyboard');
      expect(uri.queryParameters, isEmpty);
    });
  });

  group('studioStepForHarnessAgentKind', () {
    test('maps harness agents to studio steps', () {
      expect(
        studioStepForHarnessAgentKind('script_rewriter'),
        StudioStep.script,
      );
      expect(studioStepForHarnessAgentKind('extractor'), StudioStep.script);
      expect(
        studioStepForHarnessAgentKind('storyboard_breaker'),
        StudioStep.storyboard,
      );
      expect(
        studioStepForHarnessAgentKind('grid_prompt_generator'),
        StudioStep.storyboard,
      );
      expect(
        studioStepForHarnessAgentKind('voice_assigner'),
        StudioStep.assets,
      );
      expect(studioStepForHarnessAgentKind('unknown'), isNull);
    });
  });

  testWidgets('explicit route step wins over saved last step', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_42': 'storyboard',
    });

    late GoRouter router;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: '00000000-0000-0000-0000-000000000042',
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
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('body-script'), findsOneWidget);
    expect(find.text('body-storyboard'), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/projects/42/script',
    );
  });

  testWidgets('/art route selects art step body', (WidgetTester tester) async {
    late GoRouter router;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: '00000000-0000-0000-0000-000000000042',
      projectName: 'Project Delta',
      accessToken: null,
      initialStep: StudioStep.art,
      onExit: () {},
      onStepChanged: (_) {},
      onOpenAgentDrawer: () {},
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => Center(child: Text('body-${step.slug}')),
    );

    router = GoRouter(
      initialLocation: '/projects/42/art',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('body-art'), findsOneWidget);
    expect(find.text('body-script'), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/projects/42/art',
    );
  });

  testWidgets('compact bar next from script navigates to art step', (
    WidgetTester tester,
  ) async {
    late GoRouter router;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: '00000000-0000-0000-0000-000000000042',
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
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('body-script'), findsOneWidget);

    await tester.tap(find.text('Next: Art'));
    await tester.pumpAndSettle();

    expect(find.text('body-art'), findsOneWidget);
    expect(find.text('body-script'), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/projects/42/art',
    );
  });

  testWidgets('art step body shows Art direction title in studio shell', (
    WidgetTester tester,
  ) async {
    const project = ProjectRow(
      id: '00000000-0000-0000-0000-000000000042',
      numericId: 42,
      projectAccessMode: 'inherited',
      projectAccessRole: 'owner',
    );

    late GoRouter router;
    final host = ProjectStudioHost(
      projectNumericId: 42,
      projectUuid: project.id,
      projectName: 'Project Delta',
      accessToken: 'studio-test-token',
      initialStep: StudioStep.art,
      onExit: () {},
      onStepChanged: (_) {},
      onOpenAgentDrawer: () {},
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) {
        if (step != StudioStep.art) {
          return Center(child: Text('body-${step.slug}'));
        }
        return ProjectStudioArtStepPanel(
          accessToken: 'studio-test-token',
          project: project,
          catalogLoader: (
            String accessToken,
            AppLocalizations l10n,
          ) async =>
              const StylePackCatalog(
                artPacks: <StylePackOption>[],
                storyPacks: <StylePackOption>[],
              ),
          onProjectUpdated: (_) {},
          onOpenProjectSettings: () {},
        );
      },
    );

    router = GoRouter(
      initialLocation: '/projects/42/art',
      routes: <RouteBase>[
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) =>
              Scaffold(body: ProjectStudioPage(host: host)),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('Art direction'), findsOneWidget);
    expect(find.text('Save art direction'), findsOneWidget);
    expect(find.text('body-art'), findsNothing);
  });
}
