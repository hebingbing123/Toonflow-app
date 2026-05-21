import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expands the project studio cockpit when it is in compact mode.
Future<void> expandProjectStudioCockpit(WidgetTester tester) async {
  final expand = find.byKey(const Key('project_studio_cockpit_expand'));
  if (expand.evaluate().isEmpty) {
    return;
  }
  await tester.scrollUntilVisible(
    expand,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(expand);
  await tester.tap(expand);
  await tester.pumpAndSettle();
}

/// Expands a [StudioWorkbenchSection] (starters, diagnostics, etc.).
Future<void> expandStudioWorkbenchSection(WidgetTester tester) async {
  final toggle = find.byKey(const Key('studio_workbench_section_toggle'));
  if (toggle.evaluate().isEmpty) {
    return;
  }
  await tester.scrollUntilVisible(
    toggle,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}
