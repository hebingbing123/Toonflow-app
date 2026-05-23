import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_getting_started_steps.dart';
import 'package:openflow_app/project_studio/projects_studio_home.dart';
import 'package:openflow_app/projects/controller.dart';
import 'package:openflow_app/rust_api.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('projects studio home shows empty state when list is empty', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = ProjectsController(
      accessTokenProvider: () => 'token',
      onErrorChanged: (_) {},
      l10nProvider: () => null,
    );
    controller.projects = const [];
    controller.loadingProjects = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      studioGoldenApp(
        child: ProjectsStudioHome(
          accessToken: 'token',
          controller: controller,
          onOpenProjectStudio: (_) {},
          onCreateProject: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudioEmptyState), findsOneWidget);
    expect(find.byType(StudioGettingStartedSteps), findsOneWidget);
    expect(find.text('快速入门'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('uuid='), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'projects studio home hides recent rail when only one project exists',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'studio_recent_projects': <String>['project-1'],
      });
      final controller = ProjectsController(
        accessTokenProvider: () => 'token',
        onErrorChanged: (_) {},
        l10nProvider: () => null,
      );
      controller.projects = const <ProjectRow>[
        ProjectRow(
          id: 'project-1',
          numericId: 1,
          name: 'Alpha',
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
      ];
      controller.loadingProjects = false;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        studioGoldenApp(
          child: ProjectsStudioHome(
            accessToken: 'token',
            controller: controller,
            onOpenProjectStudio: (_) {},
            onCreateProject: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('继续创作'), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
