import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api/core.dart';

void main() {
  testWidgets('StudioApiErrorCallout shows retry for 503', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioApiErrorCallout(
            error: RustApiException('database_error', statusCode: 503),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });

  testWidgets('StudioApiErrorCallout stays stable on narrow layouts', (
    tester,
  ) async {
    var retried = false;
    var dismissed = false;
    await tester.binding.setSurfaceSize(const Size(360, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioApiErrorCallout(
            error: RustApiException('database_error', statusCode: 503),
            onRetry: () => retried = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    expect(retried, isTrue);
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('StudioApiErrorCallout subtle emphasis stays compact', (
    tester,
  ) async {
    var dismissed = false;
    await tester.binding.setSurfaceSize(const Size(390, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioApiErrorCallout(
            error: 'Failed to fetch',
            emphasis: StudioApiErrorCalloutEmphasis.subtle,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.textContaining('Failed to fetch'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    expectNoBenignQueuedExceptions(tester);
  });
}
