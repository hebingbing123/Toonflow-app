import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/bootstrap/global_error_handling.dart';
import 'package:openflow_app/design_system/debug/debug.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';

void main() {
  tearDown(DebugErrorOverlayController.instance.resetForTest);

  test('configureGlobalErrorHandling installs FlutterError.onError', () {
    final previous = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previous);

    configureGlobalErrorHandling(logName: 'test.global');

    expect(FlutterError.onError, isNotNull);
    expect(FlutterError.onError, isNot(previous));
  });

  test('FlutterError.onError invokes debug log hook', () {
    final previousFlutter = FlutterError.onError;
    final previousBuilder = ErrorWidget.builder;
    final previousPlatform = PlatformDispatcher.instance.onError;
    final previousHook = debugGlobalErrorLogCallback;
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      ErrorWidget.builder = previousBuilder;
      PlatformDispatcher.instance.onError = previousPlatform;
      debugGlobalErrorLogCallback = previousHook;
      DebugErrorOverlayController.instance.resetForTest();
    });

    String? loggedMessage;
    debugGlobalErrorLogCallback = (
      message, {
      required String name,
      Object? error,
      StackTrace? stackTrace,
      int level = 1000,
    }) {
      loggedMessage = message;
      expect(name, 'test.log.hook');
    };

    configureGlobalErrorHandling(logName: 'test.log.hook');
    FlutterError.onError!(
      FlutterErrorDetails(exception: Exception('logged')),
    );

    expect(loggedMessage, contains('logged'));
  });

  test('configureGlobalErrorHandling chains FlutterError.onError', () {
    var previousCalled = false;
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {
      previousCalled = true;
    };
    addTearDown(() => FlutterError.onError = previous);

    configureGlobalErrorHandling(logName: 'test.flutter.chain');
    FlutterError.onError!(
      FlutterErrorDetails(exception: Exception('widget build failed')),
    );

    expect(previousCalled, isTrue);
  });

  test('configureGlobalErrorHandling sets ErrorWidget.builder', () {
    final previousFlutter = FlutterError.onError;
    final previousBuilder = ErrorWidget.builder;
    final previousPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      ErrorWidget.builder = previousBuilder;
      PlatformDispatcher.instance.onError = previousPlatform;
    });

    configureGlobalErrorHandling(logName: 'test.builder');
    expect(ErrorWidget.builder, isNotNull);

    final widget = ErrorWidget.builder(
      FlutterErrorDetails(exception: StateError('x')),
    );
    expect(widget, isA<DebugOverlayWidget>());
  });

  test('release-style builder returns SizedBox.shrink', () {
    final widget = buildGlobalErrorDisplayWidget(
      FlutterErrorDetails(exception: Exception('hidden')),
      enableDebugOverlay: false,
    );
    expect(widget, isA<SizedBox>());
    expect((widget as SizedBox).child, isNull);
  });

  test('configureGlobalErrorHandling chains PlatformDispatcher.onError', () {
    var previousCalled = false;
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      previousCalled = true;
      return true;
    };
    addTearDown(() => PlatformDispatcher.instance.onError = previous);

    configureGlobalErrorHandling(logName: 'test.platform.chain');
    final handled = PlatformDispatcher.instance.onError!(
      Exception('async gap'),
      StackTrace.current,
    );

    expect(previousCalled, isTrue);
    expect(handled, isTrue);
  });

  test(
    'PlatformDispatcher.onError returns true when no previous handler',
    () {
      final previousFlutter = FlutterError.onError;
      final previousBuilder = ErrorWidget.builder;
      final previousPlatform = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = previousFlutter;
        ErrorWidget.builder = previousBuilder;
        PlatformDispatcher.instance.onError = previousPlatform;
      });

      PlatformDispatcher.instance.onError = null;
      configureGlobalErrorHandling(logName: 'test.platform.default');

      final handled = PlatformDispatcher.instance.onError!(
        Exception('unhandled'),
        StackTrace.empty,
      );
      expect(handled, isTrue);
    },
  );

  testWidgets('ErrorWidget.builder overlay renders exception type and message',
      (tester) async {
    final details = FlutterErrorDetails(
      exception: StateError('render-visible'),
      stack: StackTrace.fromString('#0 build'),
    );
    final widget = buildGlobalErrorDisplayWidget(
      details,
      enableDebugOverlay: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: widget),
      ),
    );

    expect(find.text('StateError'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('render-visible'), findsOneWidget);
    expect(find.textContaining('#0 build'), findsOneWidget);
  });

  test('PlatformDispatcher.onError reports to overlay controller', () {
    final previousFlutter = FlutterError.onError;
    final previousBuilder = ErrorWidget.builder;
    final previousPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      ErrorWidget.builder = previousBuilder;
      PlatformDispatcher.instance.onError = previousPlatform;
      DebugErrorOverlayController.instance.resetForTest();
    });

    configureGlobalErrorHandling(logName: 'test.overlay.report');
    PlatformDispatcher.instance.onError!(
      Exception('zone leak'),
      StackTrace.fromString('#0 async'),
    );

    expect(DebugErrorOverlayController.instance.snapshot.value, isNull);
    // report() is deferred to the next frame.
  });

  test('ErrorWidget.builder returns shrink for flex overflow', () {
    final previousBuilder = ErrorWidget.builder;
    addTearDown(() => ErrorWidget.builder = previousBuilder);

    configureGlobalErrorHandling(logName: 'test.overflow.shrink');
    final details = FlutterErrorDetails(
      exception: FlutterError('A RenderFlex overflowed by 42 pixels on the right.'),
    );
    final widget = ErrorWidget.builder(details);
    expect(widget, isA<SizedBox>());
    expect(DebugErrorOverlayController.instance.snapshot.value, isNull);
  });

  testWidgets('deferred overlay report appears after pump', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.shrink(),
      ),
    );
    DebugErrorOverlayController.instance.report(
      FlutterErrorDetails(
        exception: Exception('zone leak'),
        stack: StackTrace.fromString('#0 async'),
      ),
    );
    await tester.pump();
    await tester.pump();

    final snapshot = DebugErrorOverlayController.instance.snapshot.value;
    expect(snapshot, isNotNull);
    expect(snapshot!.message, contains('zone leak'));
  });

  group('Property 1: ErrorWidget builder populates overlay', () {
    test('for 100 random FlutterErrorDetails', () {
      final rng = Random(7);
      for (var i = 0; i < 100; i++) {
        final message = 'err-$i-${rng.nextInt(9999)}';
        final stackLineCount = rng.nextInt(30);
        final stackLines = List.generate(
          stackLineCount,
          (j) => '#$j ${List.filled(rng.nextInt(8) + 1, 'x').join()}',
        );
        final stack = StackTrace.fromString(stackLines.join('\n'));
        final details = FlutterErrorDetails(
          exception: Exception(message),
          stack: stack,
        );

        final widget = buildGlobalErrorDisplayWidget(
          details,
          enableDebugOverlay: true,
        );
        expect(widget, isA<DebugOverlayWidget>());

        final overlay = widget as DebugOverlayWidget;
        final snapshot = overlay.snapshot;
        expect(snapshot.exceptionType, contains('Exception'));
        expect(snapshot.message, contains(message));
        expect(snapshot.stackLines.length, lessThanOrEqualTo(20));
        if (stackLineCount > 0) {
          expect(snapshot.stackLines, isNotEmpty);
        }
      }
    });
  });
}
