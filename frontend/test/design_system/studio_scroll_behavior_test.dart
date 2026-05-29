import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_scroll_behavior.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/design_system/tokens.dart';

void main() {
  test('studioScrollbarTheme uses thin transparent track', () {
    final theme = studioScrollbarTheme(StudioTokens.dark);
    expect(
      theme.thickness?.resolve(<WidgetState>{}),
      lessThan(4.5),
    );
    expect(
      theme.trackColor?.resolve(<WidgetState>{}),
      Colors.transparent,
    );
    expect(theme.radius, const Radius.circular(999));
  });

  testWidgets('StudioScrollbar hides on handset width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667)),
          child: Scaffold(
            body: StudioScrollbar(
              child: ListView(
                children: const [Text('A'), Text('B')],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Scrollbar), findsNothing);
  });

  testWidgets('StudioScrollbar uses overlay thumb on wide layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        scrollBehavior: const StudioScrollBehavior(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: Scaffold(
            body: StudioScrollbar(
              forceVisible: true,
              child: ListView(
                children: List<Widget>.generate(
                  24,
                  (i) => SizedBox(height: 48, child: Text('Row $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Scrollbar), findsOneWidget);
    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.thumbVisibility, isFalse);
    expect(scrollbar.interactive, isTrue);
  });
}
