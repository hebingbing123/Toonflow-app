import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expands a collapsed [StudioWorkbenchSection] so its child actions are tappable.
Future<void> expandStudioWorkbenchSection(WidgetTester tester) async {
  final toggle = find.byKey(const Key('studio_workbench_section_toggle'));
  if (toggle.evaluate().isEmpty) {
    return;
  }

  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      toggle,
      120,
      scrollable: scrollables.first,
    );
  }
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

/// Expands every collapsed [StudioWorkbenchSection] on screen.
Future<void> expandAllStudioWorkbenchSections(WidgetTester tester) async {
  final toggles = find.byKey(const Key('studio_workbench_section_toggle'));
  final count = toggles.evaluate().length;
  for (var index = 0; index < count; index++) {
    final toggle = toggles.at(index);
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(
        toggle,
        120,
        scrollable: scrollables.first,
      );
    }
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}
