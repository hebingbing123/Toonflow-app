import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_dirty_pop_guard.dart';

void main() {
  testWidgets('StudioDirtyPopGuard builds for clean and dirty states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StudioDirtyPopGuard(
          isDirty: false,
          onConfirmDiscard: _neverConfirm,
          child: Scaffold(body: Text('clean')),
        ),
      ),
    );
    expect(find.text('clean'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: StudioDirtyPopGuard(
          isDirty: true,
          allowPop: true,
          onConfirmDiscard: _neverConfirm,
          child: Scaffold(body: Text('dirty')),
        ),
      ),
    );
    expect(find.text('dirty'), findsOneWidget);
  });
}

Future<bool> _neverConfirm() async => false;
