import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

void main() {
  testWidgets('showStudioConfirmDialog confirm is debounced', (
    WidgetTester tester,
  ) async {
    var confirmPops = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    final result = await showStudioConfirmDialog(
                      context: context,
                      title: 'Delete?',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                    if (result == true) {
                      confirmPops++;
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(confirmPops, 1);
  });

  testWidgets('onConfirmAction ignores rapid double confirm taps', (
    WidgetTester tester,
  ) async {
    var actionRuns = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(
                      showStudioConfirmDialog(
                        context: context,
                        title: 'Delete?',
                        confirmLabel: 'Delete',
                        destructive: true,
                        onConfirmAction: () async {
                          actionRuns++;
                          await Future<void>.delayed(
                            const Duration(milliseconds: 80),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    expect(actionRuns, 1);
  });

  testWidgets('showStudioConfirmDialog runs onConfirmAction before pop', (
    WidgetTester tester,
  ) async {
    var actionRuns = 0;
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    dialogResult = await showStudioConfirmDialog(
                      context: context,
                      title: 'Delete?',
                      confirmLabel: 'Delete',
                      destructive: true,
                      onConfirmAction: () async {
                        actionRuns++;
                        await Future<void>.delayed(
                          const Duration(milliseconds: 30),
                        );
                      },
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(actionRuns, 1);
    expect(dialogResult, isTrue);
  });
}
