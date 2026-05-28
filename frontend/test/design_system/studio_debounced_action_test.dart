import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_debounced_action.dart';

void main() {
  testWidgets('StudioDebouncedAction ignores rapid double taps', (
    WidgetTester tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioDebouncedAction(
            duration: const Duration(milliseconds: 200),
            onPressed: () async {
              presses++;
              await Future<void>.delayed(const Duration(milliseconds: 50));
            },
            builder: (context, onPressed) {
              return FilledButton(
                onPressed: onPressed,
                child: const Text('Submit'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(presses, 1);
  });
}
