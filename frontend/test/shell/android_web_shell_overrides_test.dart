import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_mobile_affordances.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/shell/android_web_shell_overrides.dart';

void main() {
  group('androidWebShellOverridesEnabled', () {
    test('is false in the Flutter test environment', () {
      expect(StudioMobileAffordances.supportsAndroidWebBack, isFalse);
      expect(androidWebShellOverridesEnabled(), isFalse);
      expect(shouldInstallAndroidWebPopStateListener, isFalse);
    });
  });

  group('wrapAndroidWebScrollBehaviour', () {
    testWidgets('returns child unchanged when overrides are inactive',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.build(),
          home: Builder(
            builder: (context) {
              return wrapAndroidWebScrollBehaviour(
                const KeyedSubtree(
                  key: ValueKey('scroll-marker'),
                  child: SizedBox(height: 100),
                ),
                enableOverrides: false,
              );
            },
          ),
        ),
      );

      expect(find.byKey(const ValueKey('scroll-marker')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ScrollConfiguration &&
              widget.behavior is AndroidWebClampingScrollBehaviour,
        ),
        findsNothing,
      );
    });

    testWidgets('wraps with clamping scroll behavior when overrides are enabled',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.build(),
          home: Builder(
            builder: (context) {
              return wrapAndroidWebScrollBehaviour(
                const SizedBox(height: 100),
                enableOverrides: true,
              );
            },
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ScrollConfiguration &&
              widget.behavior is AndroidWebClampingScrollBehaviour,
        ),
        findsOneWidget,
      );
    });
  });

  group('wrapAndroidWebTheme', () {
    testWidgets('returns child unchanged when overrides are inactive',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.build(),
          home: Builder(
            builder: (context) {
              return wrapAndroidWebTheme(
                context,
                const KeyedSubtree(
                  key: ValueKey('theme-marker'),
                  child: SizedBox(),
                ),
                enableOverrides: false,
              );
            },
          ),
        ),
      );

      expect(find.byKey(const ValueKey('theme-marker')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('theme-marker')),
          matching: find.byType(Theme),
        ),
        findsNothing,
      );
    });

    testWidgets('wraps with Theme when overrides are enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.build(),
          home: Builder(
            builder: (context) {
              return wrapAndroidWebTheme(
                context,
                Builder(
                  builder: (innerContext) {
                    final theme = Theme.of(innerContext);
                    expect(theme.splashFactory, InkRipple.splashFactory);
                    expect(
                      theme.highlightColor,
                      StudioPrimitives.transparent,
                    );
                    return const SizedBox(key: ValueKey('themed'));
                  },
                ),
                enableOverrides: true,
              );
            },
          ),
        ),
      );

      expect(find.byKey(const ValueKey('themed')), findsOneWidget);
    });
  });

  group('installAndroidWebPopStateListenerIfNeeded', () {
    testWidgets('does not install when supportsAndroidWebBack is false',
        (tester) async {
      Object? subscription;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              subscription = installAndroidWebPopStateListenerIfNeeded(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(StudioMobileAffordances.supportsAndroidWebBack, isFalse);
      expect(subscription, isNull);
    });
  });
}
