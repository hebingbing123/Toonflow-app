import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_audit/runtime/audit_fixtures.dart';
import 'package:ui_audit/runtime/responsive_behavior_inspector.dart';

void main() {
  testWidgets('Property 15: detects child wider than viewport', (tester) async {
    final fixture = builtInAuditFixtures().firstWhere(
      (f) => f.name == 'fixed_width_panel',
    );

    tester.view.physicalSize = const Size(520, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: fixture.widget)));
    await tester.pumpAndSettle();

    final findings = ResponsiveBehaviorInspector().inspect(
      tester,
      fixtureName: fixture.name,
      viewportWidth: 520,
    );

    expect(
      findings.any((f) => f.title.contains('Fixed-width element')),
      isTrue,
    );
  });
}
