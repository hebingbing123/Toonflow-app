import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/project_studio/studio_step_progress_ring.dart';

void main() {
  testWidgets('StudioStepProgressRing shows completed count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: const Scaffold(
          body: StudioStepProgressRing(completedSteps: 3),
        ),
      ),
    );
    expect(find.text('3/6'), findsOneWidget);
  });
}
