import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../models/models.dart';
import 'accessibility_inspector_runtime.dart';
import 'audit_fixtures.dart';
import 'empty_state_inspector.dart';
import 'interactive_element_inspector.dart';
import 'responsive_behavior_inspector.dart';
import 'runtime_inspector.dart';
import 'widget_tree_inspector.dart';

/// Runs headless widget tests against built-in audit fixtures.
class FlutterRuntimeInspector implements RuntimeInspector {
  final WidgetTreeInspector widgetTreeInspector;
  final InteractiveElementInspector interactiveInspector;
  final EmptyStateInspector emptyStateInspector;
  final ResponsiveBehaviorInspector responsiveInspector;
  final AccessibilityInspectorRuntime accessibilityInspector;
  final List<AuditFixture> fixtures;

  FlutterRuntimeInspector({
    WidgetTreeInspector? widgetTreeInspector,
    InteractiveElementInspector? interactiveInspector,
    EmptyStateInspector? emptyStateInspector,
    ResponsiveBehaviorInspector? responsiveInspector,
    AccessibilityInspectorRuntime? accessibilityInspector,
    List<AuditFixture>? fixtures,
  })  : widgetTreeInspector = widgetTreeInspector ?? WidgetTreeInspector(),
        interactiveInspector = interactiveInspector ?? InteractiveElementInspector(),
        emptyStateInspector = emptyStateInspector ?? EmptyStateInspector(),
        responsiveInspector = responsiveInspector ?? ResponsiveBehaviorInspector(),
        accessibilityInspector =
            accessibilityInspector ?? AccessibilityInspectorRuntime(),
        fixtures = fixtures ?? builtInAuditFixtures();

  @override
  Future<RuntimeInspectionResult> inspect(RuntimeInspectionContext context) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.textScaleFactorTestValue = 1.0;

    final findings = <Finding>[];
    final errors = <AuditError>[];
    var widgetsInspected = 0;

    final breakpoints = context.breakpoints.isEmpty
        ? const [520, 720, 1100]
        : context.breakpoints;

    for (final fixture in fixtures) {
      for (final width in breakpoints) {
        try {
          await _inspectFixture(
            fixture: fixture,
            viewportWidth: width,
            findings: findings,
            onWidgetsInspected: () => widgetsInspected++,
          );
        } catch (e, stack) {
          errors.add(
            AuditError(
              phase: 'runtime_inspection',
              file: fixture.name,
              message: 'Fixture failed at ${width}px: $e',
              stackTrace: stack.toString(),
            ),
          );
        }
      }
    }

    return RuntimeInspectionResult(
      findings: findings,
      errors: errors,
      widgetsInspected: widgetsInspected,
    );
  }

  Future<void> _inspectFixture({
    required AuditFixture fixture,
    required int viewportWidth,
    required List<Finding> findings,
    required VoidCallback onWidgetsInspected,
  }) async {
  await benchmarkWidgets((tester) async {
    tester.view.physicalSize = Size(viewportWidth.toDouble(), 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: fixture.widget),
      ),
    );
    await tester.pumpAndSettle();

    onWidgetsInspected();

    final root = tester.binding.rootElement;
    if (root != null) {
      widgetTreeInspector.inspect(root);
    }

    findings.addAll(
      interactiveInspector.inspect(
        tester,
        fixtureName: fixture.name,
        viewportWidth: viewportWidth,
      ),
    );
    findings.addAll(
      emptyStateInspector.inspect(tester, fixtureName: fixture.name),
    );
    findings.addAll(
      responsiveInspector.inspect(
        tester,
        fixtureName: fixture.name,
        viewportWidth: viewportWidth,
      ),
    );
    findings.addAll(
      accessibilityInspector.inspect(tester, fixtureName: fixture.name),
    );
  });
  }
}
