import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_form_keyboard.dart';

void main() {
  testWidgets('StudioFormKeyboardScope submits batch-add style dialog', (
    WidgetTester tester,
  ) async {
    var submitted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioFormKeyboardScope(
            onEnterSubmit: () => submitted = true,
            child: const TextField(
              key: Key('batch-count'),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('batch-count')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submitted, isTrue);
  });

  testWidgets('StudioFormKeyboardScope submits asset create dialog fields', (
    WidgetTester tester,
  ) async {
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioFormKeyboardScope(
            onEnterSubmit: () => saved = true,
            child: const TextField(
              key: Key('asset-name'),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('asset-name')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('URL field Enter opens site; other fields capture cookies', (
    WidgetTester tester,
  ) async {
    final urlCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    addTearDown(urlCtrl.dispose);
    addTearDown(noteCtrl.dispose);
    var openedUrl = false;
    var captured = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioFormKeyboardScope(
            onEnterSubmit: () {
              final controller = studioFocusedTextField(
                FocusManager.instance.primaryFocus?.context,
              )?.controller;
              if (controller == urlCtrl) {
                openedUrl = true;
                return;
              }
              captured = true;
            },
            child: Column(
              children: [
                TextField(
                  key: const Key('crawl-url'),
                  controller: urlCtrl,
                  maxLines: 1,
                ),
                TextField(
                  key: const Key('crawl-note'),
                  controller: noteCtrl,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('crawl-url')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(openedUrl, isTrue);
    expect(captured, isFalse);

    await tester.tap(find.byKey(const Key('crawl-note')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(captured, isTrue);
  });

  testWidgets('plan workbench style scope invokes onSave on Enter', (
    WidgetTester tester,
  ) async {
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioFormKeyboardScope(
            onEnterSubmit: () => saved = true,
            child: TextField(
              key: const Key('plan-field'),
              controller: TextEditingController(text: 'outline'),
              minLines: 6,
              maxLines: 10,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('plan-field')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(saved, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioFormKeyboardScope(
            onEnterSubmit: () => saved = true,
            child: const TextField(
              key: Key('plan-single'),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('plan-single')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('launcher dialog scope pops true on Enter', (
    WidgetTester tester,
  ) async {
  bool? popped;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    popped = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) {
                        return AlertDialog(
                          content: StudioFormKeyboardScope(
                            onEnterSubmit: () =>
                                Navigator.of(dialogCtx).pop(true),
                            child: const TextField(
                              key: Key('clip-name'),
                              maxLines: 1,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogCtx).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ],
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
    await tester.tap(find.byKey(const Key('clip-name')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(popped, isTrue);
  });
}
