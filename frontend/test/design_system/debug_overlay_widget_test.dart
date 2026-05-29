import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/debug/debug.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';

void main() {
  Future<void> pumpOverlay(
    WidgetTester tester, {
    required DebugErrorSnapshot snapshot,
    Size viewport = const Size(400, 800),
  }) async {
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DebugOverlayWidget(snapshot: snapshot),
        ),
      ),
    );
    await tester.pump();
  }

  group('DebugOverlayWidget', () {
    testWidgets('collapsed height is at least 48 logical pixels', (tester) async {
      const snapshot = DebugErrorSnapshot(
        exceptionType: 'StateError',
        message: 'bad state',
        stackLines: ['#0 main'],
      );
      await pumpOverlay(tester, snapshot: snapshot);

      final box = tester.renderObject<RenderBox>(
        find.byType(AnimatedContainer),
      );
      expect(box.size.height, greaterThanOrEqualTo(StudioSpacing.touchTarget));
    });

    testWidgets('header tap toggles expand and collapse', (tester) async {
      const snapshot = DebugErrorSnapshot(
        exceptionType: 'FlutterError',
        message: 'build failed',
        stackLines: ['#0 build'],
      );
      await pumpOverlay(tester, snapshot: snapshot);

      expect(find.byType(SingleChildScrollView), findsNothing);

      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SingleChildScrollView), findsNothing);

      final box = tester.renderObject<RenderBox>(
        find.byType(AnimatedContainer),
      );
      expect(box.size.height, greaterThanOrEqualTo(StudioSpacing.touchTarget));
    });

    testWidgets('copy button writes fullText to clipboard', (tester) async {
      const snapshot = DebugErrorSnapshot(
        exceptionType: 'FormatException',
        message: 'invalid input',
        stackLines: ['#0 parse'],
      );
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) async {
        if (message.method == 'Clipboard.setData') {
          final args = message.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
          return null;
        }
        return null;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await pumpOverlay(tester, snapshot: snapshot);
      await tester.tap(find.byIcon(Icons.copy_outlined));
      await tester.pump();

      expect(clipboardText, snapshot.fullText);
    });

    testWidgets('empty message and stack show fallback text when expanded',
        (tester) async {
      const snapshot = DebugErrorSnapshot(
        exceptionType: 'Error',
        message: '   ',
        stackLines: [],
      );
      await pumpOverlay(tester, snapshot: snapshot);

      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await tester.pumpAndSettle();

      expect(find.text('No details available'), findsOneWidget);
    });
  });

  group('Property 2: collapse–expand–collapse round-trip', () {
    testWidgets('restores collapsed state after 100 random snapshots',
        (tester) async {
      final rng = Random(42);
      for (var i = 0; i < 100; i++) {
        final message = rng.nextBool() ? 'msg-$i' : '';
        final stackLines = rng.nextBool()
            ? List.generate(rng.nextInt(5) + 1, (j) => '#$j frame')
            : <String>[];
        final snapshot = DebugErrorSnapshot(
          exceptionType: 'Ex$i',
          message: message,
          stackLines: stackLines,
        );

        await pumpOverlay(
          tester,
          snapshot: snapshot,
          viewport: Size(360, 640 + (i % 3) * 40),
        );

        await tester.tap(find.byIcon(Icons.bug_report_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(SingleChildScrollView), findsOneWidget);

        await tester.tap(find.byIcon(Icons.bug_report_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(SingleChildScrollView), findsNothing);

        final box = tester.renderObject<RenderBox>(
          find.byType(AnimatedContainer),
        );
        expect(
          box.size.height,
          greaterThanOrEqualTo(StudioSpacing.touchTarget),
          reason: 'iteration $i',
        );
      }
    });
  });
}
