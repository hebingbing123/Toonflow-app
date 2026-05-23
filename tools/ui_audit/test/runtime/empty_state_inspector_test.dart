import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_audit/runtime/audit_fixtures.dart';
import 'package:ui_audit/runtime/empty_state_inspector.dart';

void main() {
  testWidgets('Property 14: detects list without empty state treatment', (tester) async {
    final fixture = builtInAuditFixtures().firstWhere(
      (f) => f.name == 'empty_list_without_treatment',
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: fixture.widget)));
    await tester.pumpAndSettle();

    final findings = EmptyStateInspector().inspect(
      tester,
      fixtureName: fixture.name,
    );

    expect(
      findings.any((f) => f.title.contains('Empty state treatment missing')),
      isTrue,
    );
  });
}
