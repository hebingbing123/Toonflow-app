import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ignore_layout_overflow.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/native_bridge/native_bridge_bootstrap.dart';
import 'package:openflow_app/native_bridge/native_bridge_bootstrap_platform.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/status_page.dart';

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
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('status page renders desktop bridge ready details', (
    WidgetTester tester,
  ) async {
    final bootstrap = NativeBridgeBootstrap(
      platformSupport: const _TestPlatformSupport(),
      initializeDefault: () async => throw StateError('default failed'),
      initializeFromPath: (path) async {
        if (path != 'bundle/Frameworks/libopenflow_core_bridge.dylib') {
          throw StateError('not here');
        }
      },
    );
    await bootstrap.ensureStarted();

    await tester.pumpWidget(
      _buildApp(
        StatusPage(
          bootstrap: bootstrap,
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

    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(find.text(l10n.statusPageDesktopBridgeSectionTitle), findsOneWidget);
    expect(find.text(l10n.statusPageBridgeStateLine('ready')), findsOneWidget);
    expect(
      find.text(
        l10n.statusPageBridgeMessageLine(
          l10n.nativeBridgeMessageLoadedFrom(
            'bundle/Frameworks/libopenflow_core_bridge.dylib',
          ),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'library_path=bundle/Frameworks/libopenflow_core_bridge.dylib',
      ),
      findsOneWidget,
    );
  });

  testWidgets('status page renders desktop bridge failure details', (
    WidgetTester tester,
  ) async {
    final bootstrap = NativeBridgeBootstrap(
      platformSupport: const _TestPlatformSupport(),
      initializeDefault: () async => throw StateError('default failed'),
      initializeFromPath: (_) async => throw StateError('fallback failed'),
    );
    await bootstrap.ensureStarted();

    await tester.pumpWidget(
      _buildApp(
        StatusPage(
          bootstrap: bootstrap,
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

    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(find.text(l10n.statusPageDesktopBridgeSectionTitle), findsOneWidget);
    expect(find.text(l10n.statusPageBridgeStateLine('failed')), findsOneWidget);
    expect(
      find.text(
        l10n.statusPageBridgeMessageLine(l10n.nativeBridgeMessageInitFailed),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        l10n.statusPageBridgeErrorLine('Bad state: fallback failed'),
      ),
      findsOneWidget,
    );
  });
}

class _TestPlatformSupport extends NativeBridgePlatformSupport {
  const _TestPlatformSupport();

  @override
  bool get supportsExplicitLibraryLoading => true;

  @override
  List<String> candidateLibraryPaths() => const [
    'bundle/Frameworks/libopenflow_core_bridge.dylib',
  ];
}
