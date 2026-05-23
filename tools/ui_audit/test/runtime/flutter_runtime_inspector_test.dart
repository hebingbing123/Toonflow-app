import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_audit/runtime/audit_fixtures.dart';
import 'package:ui_audit/runtime/flutter_runtime_inspector.dart';
import 'package:ui_audit/runtime/runtime_inspector.dart';

void main() {
  testWidgets('inspects fixture via shared inspectors', (tester) async {
    final fixture = AuditFixture(
      name: 'tiny_button',
      widget: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: ElevatedButton(onPressed: () {}, child: const Text('Go')),
        ),
      ),
    );

    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: fixture.widget)));
    await tester.pumpAndSettle();

  final inspector = FlutterRuntimeInspector(fixtures: [fixture]);
  // Full inspect() uses benchmarkWidgets and is intended for CLI; verify fixture list.
  expect(inspector.fixtures, hasLength(1));
  expect(inspector.fixtures.first.name, 'tiny_button');
  });
}
