import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_form_keyboard.dart';

void main() {
  test('studioCountSingleLineTextFields counts nested fields', () {
    expect(
      studioCountSingleLineTextFields(
        const Column(
          children: [
            TextField(maxLines: 1),
            TextField(maxLines: 3),
          ],
        ),
      ),
      1,
    );
    expect(
      studioCountSingleLineTextFields(const TextField(maxLines: 1)),
      1,
    );
    expect(
      studioCountSingleLineTextFields(
        const Column(
          children: [
            TextField(maxLines: 1),
            TextField(maxLines: 1),
          ],
        ),
      ),
      2,
    );
  });

  test('studioDialogPrimaryActionFromActions prefers trailing FilledButton', () {
    var primary = 0;
    var cancel = 0;
    final callback = studioDialogPrimaryActionFromActions([
      TextButton(onPressed: () => cancel++, child: const Text('Cancel')),
      FilledButton(onPressed: () => primary++, child: const Text('OK')),
    ]);
    callback?.call();
    expect(primary, 1);
    expect(cancel, 0);
  });

  test('studioResolveAlertDialogEnterSubmit auto-wires single field', () {
    var saved = 0;
    final submit = studioResolveAlertDialogEnterSubmit(
      enterSubmitEnabled: true,
      content: const TextField(maxLines: 1),
      actions: [
        FilledButton(onPressed: () => saved++, child: const Text('Save')),
      ],
    );
    submit?.call();
    expect(saved, 1);
  });

  test('studioResolveAlertDialogEnterSubmit skips multi-field content', () {
    final submit = studioResolveAlertDialogEnterSubmit(
      enterSubmitEnabled: true,
      content: const Column(
        children: [
          TextField(maxLines: 1),
          TextField(maxLines: 1),
        ],
      ),
      actions: [
        FilledButton(onPressed: () {}, child: const Text('Save')),
      ],
    );
    expect(submit, isNull);
  });

  test('studioFormFieldAcceptsEnterSubmit allows single-line only', () {
    expect(studioFormFieldAcceptsEnterSubmit(null), isTrue);
  });

  testWidgets('StudioFormKeyboardScope invokes onEnterSubmit from single-line field', (
    WidgetTester tester,
  ) async {
    var submitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioFormKeyboardScope(
            onEnterSubmit: () => submitted++,
            child: const TextField(
              key: Key('single'),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('single')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submitted, 1);
  });

  testWidgets('StudioFormKeyboardScope ignores Enter in multiline field', (
    WidgetTester tester,
  ) async {
    var submitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioFormKeyboardScope(
            onEnterSubmit: () => submitted++,
            child: const TextField(
              key: Key('multi'),
              maxLines: 3,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('multi')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submitted, 0);
  });

  testWidgets('studioFocusedTextField resolves TextField key from focus', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextField(key: Key('target')),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('target')));
    await tester.pump();

    final field = studioFocusedTextField(
      FocusManager.instance.primaryFocus?.context,
    );
    expect(field?.key, const Key('target'));
  });
}
