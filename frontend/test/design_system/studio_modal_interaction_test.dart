import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/studio_modal_presentation.dart';
import 'package:openflow_app/design_system/theme.dart';

void main() {
  group('studioModalPresentationFor', () {
    test('non scroll-controlled stays bottom sheet', () {
      expect(
        studioModalPresentationFor(isScrollControlled: false),
        StudioModalPresentation.bottomSheet,
      );
    });

    test('scroll-controlled on VM test host stays bottom sheet', () {
      expect(kIsWeb, isFalse);
      expect(
        studioModalPresentationFor(isScrollControlled: true),
        StudioModalPresentation.bottomSheet,
      );
    });
  });

  testWidgets('StudioWebTallSheetDialog scrolls, primary tap, close removes barrier', (
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
                  builder: (ctx) => StudioWebTallSheetDialog(
                    child: SizedBox(
                      height: 480,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Expanded(child: Text('Tall panel')),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                          Expanded(
                            child: ListView(
                              children: List<Widget>.generate(
                                12,
                                (i) => ListTile(title: Text('Row $i')),
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop('ok'),
                            child: const Text('Continue'),
                          ),
                        ],
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

    expect(find.byType(ModalBarrier), findsWidgets);
    expect(find.text('Tall panel'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Tall panel'), findsNothing);
  });

  testWidgets('showStudioConfirmDialog cancel pops false', (
    WidgetTester tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showStudioConfirmDialog(
                  context: context,
                  title: 'Delete?',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Keep',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('Delete?'), findsNothing);
  });

  testWidgets('showStudioConfirmDialog confirm pops true', (
    WidgetTester tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showStudioConfirmDialog(
                  context: context,
                  title: 'Delete?',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Keep',
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('Delete?'), findsNothing);
  });

  testWidgets('showStudioBottomSheet scroll-controlled opens ModalBarrier', (
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
                showStudioBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => SizedBox(
                    height: 400,
                    child: StudioDialogShell(
                      title: 'Setup',
                      scrollable: true,
                      onClose: () => Navigator.of(ctx).pop(),
                      child: const Text('Body'),
                    ),
                  ),
                );
              },
              child: const Text('sheet'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(ModalBarrier), findsWidgets);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('Setup'), findsNothing);
  });
}
