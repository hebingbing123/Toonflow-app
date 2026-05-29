import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/theme.dart';

void main() {
  testWidgets('StudioDialogShell non-scrollable body uses loose Flexible', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showStudioDialog<void>(
                  context: context,
                  builder: (ctx) => StudioDialogShell(
                    title: 'Workflow',
                    scrollable: false,
                    onClose: () => Navigator.of(ctx).pop(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(
                        5,
                        (i) => ListTile(title: Text('Item $i')),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(Flexible), findsOneWidget);
    expect(find.text('Workflow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('StudioDialogShell scrollable body uses scroll view', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showStudioDialog<void>(
                  context: context,
                  builder: (ctx) => StudioDialogShell(
                    title: 'Scrollable',
                    scrollable: true,
                    onClose: () => Navigator.of(ctx).pop(),
                    child: Column(
                      children: List<Widget>.generate(
                        8,
                        (i) => ListTile(title: Text('Line $i')),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open-scroll'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-scroll'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(Scrollable), findsWidgets);
    expect(find.text('Scrollable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
