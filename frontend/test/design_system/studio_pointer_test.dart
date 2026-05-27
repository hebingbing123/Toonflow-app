import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_tap.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';
import 'package:openflow_app/design_system/ix/studio_pointer.dart';
import 'package:openflow_app/design_system/ix/studio_scroll_behavior.dart';
import 'package:openflow_app/design_system/theme.dart';

void main() {
  testWidgets('StudioTap enables pointer chrome on wide desktop layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        scrollBehavior: const StudioScrollBehavior(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: Scaffold(
            body: Center(
              child: StudioTap(
                onTap: () {},
                child: const Text('Tap me'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      studioPointerChromeEnabled(tester.element(find.byType(StudioTap))),
      isTrue,
    );
    expect(find.byType(StudioPointerHover), findsOneWidget);
  });

  testWidgets('studioBuildListRowContextMenu orders destructive actions last', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final items = studioBuildListRowContextMenu(
              context: context,
              onTap: () {},
              onCopy: () {},
              onDelete: () {},
            );
            expect(items.first.label, isNotEmpty);
            expect(items.last.destructive, isTrue);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('Material buttons use click cursor from theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: Scaffold(
          body: FilledButton(
            onPressed: () {},
            child: const Text('Go'),
          ),
        ),
      ),
    );

    final style = Theme.of(tester.element(find.byType(FilledButton))).filledButtonTheme.style;
    expect(
      style?.mouseCursor?.resolve(<WidgetState>{}),
      SystemMouseCursors.click,
    );
  });
}
