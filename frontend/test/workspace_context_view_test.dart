import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/shell/workspace_context_view.dart';

void main() {
  testWidgets('workspace context view renders workspace and project scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkspaceContextView(
            loading: false,
            workspaceName: 'Personal Workspace',
            workspaceType: 'personal',
            projectLabel: 'Project #12 · Palace Episode',
          ),
        ),
      ),
    );

    expect(find.text('Personal Workspace'), findsOneWidget);
    expect(find.text('personal'), findsOneWidget);
    expect(find.text('Project #12 · Palace Episode'), findsOneWidget);
  });
}
