import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_audit/models/models.dart';
import 'package:ui_audit/runtime/audit_fixtures.dart';
import 'package:ui_audit/runtime/interactive_element_inspector.dart';

void main() {
  group('InteractiveElementInspector', () {
    testWidgets('Property 9: flags undersized icon button touch target', (tester) async {
      final fixture = builtInAuditFixtures().firstWhere(
        (f) => f.name == 'small_icon_button',
      );

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: fixture.widget)));
      await tester.pumpAndSettle();

      final findings = InteractiveElementInspector().inspect(
        tester,
        fixtureName: fixture.name,
        viewportWidth: 800,
      );

      expect(
        findings.any((f) => f.title.contains('Touch target too small')),
        isTrue,
      );
      expect(findings.first.category, FindingCategory.interactiveElements);
    });

    testWidgets('Property 11: flags disabled opacity out of range', (tester) async {
      final fixture = builtInAuditFixtures().firstWhere(
        (f) => f.name == 'disabled_button_low_opacity',
      );

      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: fixture.widget)));
      await tester.pumpAndSettle();

      final findings = InteractiveElementInspector().inspect(
        tester,
        fixtureName: fixture.name,
        viewportWidth: 800,
      );

      expect(
        findings.any((f) => f.title.contains('Disabled state opacity')),
        isTrue,
      );
    });
  });
}
