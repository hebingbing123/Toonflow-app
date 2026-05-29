import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/rust_api/search/api.dart';

void main() {
  group('studio hero tags', () {
    test('project tags are unique per numeric id', () {
      expect(
        studioHeroTagProjectProgress(1),
        isNot(studioHeroTagProjectProgress(2)),
      );
      expect(
        studioHeroTagProjectTitle(1),
        isNot(studioHeroTagProjectTitle(2)),
      );
    });

    test('search tags encode type and id', () {
      final tag = studioHeroTagSearchResultLeading(
        ResultType.asset,
        'abc',
      );
      expect(tag, contains('asset'));
      expect(tag, contains('abc'));
    });
  });

  group('studioStaggeredChildren', () {
    test('wraps each child with stagger index', () {
      final wrapped = studioStaggeredChildren(
        const [Text('a'), Text('b')],
        entranceKey: 2,
      );
      expect(wrapped, hasLength(2));
      expect(wrapped.first, isA<StudioStaggeredEntrance>());
    });
  });

  group('StudioStaggeredEntrance', () {
    testWidgets('shows child immediately when animations disabled', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: StudioStaggeredEntrance(
                index: 0,
                child: Text('row'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('row'), findsOneWidget);
    });
  });

  group('StudioHero', () {
    testWidgets('does not register hero when route is not current', (
      tester,
    ) async {
      const tag = 'studio-hero-test';
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/top') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (context) => const Scaffold(
                  body: Text('foreground'),
                ),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => Scaffold(
                body: StudioHero(
                  tag: tag,
                  child: const Text('background'),
                ),
              ),
            );
          },
          initialRoute: '/',
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/top');
      await tester.pumpAndSettle();
      expect(find.byType(Hero), findsNothing);
    });
  });

  group('StudioFadeSwitcher', () {
    testWidgets('swaps keyed children', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: StudioFadeSwitcher(
                  transitionKey: 'a',
                  child: const Text('A'),
                ),
              );
            },
          ),
        ),
      );
      expect(find.text('A'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioFadeSwitcher(
              transitionKey: 'b',
              child: const Text('B'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('B'), findsOneWidget);
    });
  });
}
