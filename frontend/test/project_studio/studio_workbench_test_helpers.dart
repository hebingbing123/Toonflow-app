import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the step Setup sheet (focus mode keeps cockpit/agents off the canvas).
Future<void> openProjectStudioStepSetup(WidgetTester tester) async {
  final setupLabel = find.text('Setup');
  if (setupLabel.evaluate().isNotEmpty) {
    await tester.tap(setupLabel);
    await tester.pumpAndSettle();
    return;
  }
  final setupIcon = find.byIcon(Icons.playlist_add_check_outlined);
  if (setupIcon.evaluate().isNotEmpty) {
    await tester.tap(setupIcon.first);
    await tester.pumpAndSettle();
  }
}

/// Opens the workspace / more-steps menu on the compact journey bar.
Future<void> openProjectStudioWorkspaceMenu(WidgetTester tester) async {
  final tune = find.byIcon(Icons.tune_rounded);
  if (tune.evaluate().isEmpty) {
    await tester.tap(find.text('Workspace'));
  } else {
    await tester.tap(tune.last);
  }
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
