import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/status_page.dart';
import 'package:openflow_app/rust_api.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  test('shouldOpenStatusPageForInitialUri only matches status route', () {
    expect(shouldOpenStatusPageForInitialUri(Uri.parse('/status')), isTrue);
    expect(shouldOpenStatusPageForInitialUri(Uri.parse('/status/')), isTrue);
    expect(shouldOpenStatusPageForInitialUri(Uri.parse('/product')), isFalse);
  });

  testWidgets('status page renders refreshed metric cards without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(
        StatusPage(
          fetchers: StatusPageFetchers(
            fetchHealthRoot: () async =>
                const HealthResponse(status: 'ok', service: 'openflow'),
            fetchHealthV1: () async =>
                const HealthResponse(status: 'ok', service: 'openflow'),
            fetchReadyV1: () async =>
                const ReadyV1Response(status: 'ready', database: 'connected'),
            fetchVersionV1: () async => const VersionResponse(
              service: 'openflow',
              version: '1.2.3',
              gitSha: 'abc123',
            ),
            fetchJobQueueStats: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('公开只读状态页'), findsOneWidget);
    expect(find.text('/health'), findsOneWidget);
    expect(find.text('/api/v1/health'), findsOneWidget);
    expect(find.text('/api/v1/ready'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    expect(find.textContaining('API：'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
