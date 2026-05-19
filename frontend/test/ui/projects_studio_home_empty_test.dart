import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/project_studio/projects_studio_home.dart';
import 'package:openflow_app/projects/controller.dart';

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
    expect(find.textContaining('uuid='), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
