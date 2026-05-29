import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the step Setup sheet (focus mode keeps cockpit/agents off the canvas).
Future<void> openProjectStudioStepSetup(WidgetTester tester) async {
  final setupLabel = find.text('Setup');
  if (setupLabel.evaluate().isNotEmpty) {
    await tester.tap(setupLabel.first);
    await tester.pumpAndSettle();
    return;
  }
  final setupIcon = find.byIcon(Icons.playlist_add_check_outlined);
  if (setupIcon.evaluate().isNotEmpty) {
    await tester.tap(setupIcon.first);
    await tester.pumpAndSettle();
    return;
  }
  final collapsedTools = find.byIcon(Icons.more_horiz_rounded);
  if (collapsedTools.evaluate().isNotEmpty) {
    await tester.tap(collapsedTools.last);
    await tester.pumpAndSettle();
    final setupInSheet = find.text('Setup');
    if (setupInSheet.evaluate().isNotEmpty) {
      await tester.tap(setupInSheet.first);
      await tester.pumpAndSettle();
    }
  }
}

/// Taps the compact journey bar "next" control (text or icon-only).
Future<void> tapProjectStudioCompactBarNext(
  WidgetTester tester, {
  String? nextLabel,
}) async {
  if (nextLabel != null) {
    final text = find.text(nextLabel);
    if (text.evaluate().isNotEmpty) {
      await tester.tap(text);
      await tester.pumpAndSettle();
      return;
    }
  }
  final icons = find.byIcon(Icons.arrow_forward_rounded);
  expect(icons, findsWidgets);
  await tester.tap(icons.last);
  await tester.pumpAndSettle();
}

/// Asserts the header progress ring label (allows animated number settle).
Future<void> expectStudioStepProgressRing(
  WidgetTester tester,
  String label,
) async {
  await tester.pump(const Duration(milliseconds: 350));
  expect(find.text(label), findsOneWidget);
}

/// Opens the workspace / more-steps menu on the compact journey bar.
Future<void> openProjectStudioWorkspaceMenu(WidgetTester tester) async {
  final tune = find.byIcon(Icons.tune_rounded);
  if (tune.evaluate().isNotEmpty) {
    await tester.tap(tune.last);
    await tester.pumpAndSettle();
    return;
  }
  final collapsedTools = find.byIcon(Icons.more_horiz_rounded);
  if (collapsedTools.evaluate().isNotEmpty) {
    await tester.tap(collapsedTools.last);
    await tester.pumpAndSettle();
    return;
  }
  await tester.tap(find.text('Workspace'));
  await tester.pumpAndSettle();
}

/// Default surface for studio widget tests (avoids focus-mode chrome overflow).
Future<void> ensureProjectStudioTestSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
}

/// Expands the project studio cockpit when it is in compact mode.
Future<void> expandProjectStudioCockpit(WidgetTester tester) async {
  var expand = find.byKey(const Key('project_studio_cockpit_expand'));
  if (expand.evaluate().isEmpty) {
    await openProjectStudioStepSetup(tester);
    expand = find.byKey(const Key('project_studio_cockpit_expand'));
  }
  if (expand.evaluate().isEmpty) {
    return;
  }
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    try {
      await tester.scrollUntilVisible(
        expand,
        80,
        scrollable: scrollables.last,
      );
    } catch (_) {
      // Sheet may already show the expand control.
    }
  }
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
