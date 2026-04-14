import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/overview/section_view.dart';

void noop() {}

OverviewSectionViewModel buildModel({
  bool loadingHealth = false,
  bool loadingHealthRoot = false,
  bool loadingPing = false,
  bool loadingVersion = false,
  bool loadingReady = false,
  String? healthBody = '{"ok":true}',
  String? healthRootBody = '{"root":true}',
  String? pingBody = 'pong',
  String? versionBody = '{"version":"1.0.0"}',
  String? readyBody = '{"ready":true}',
}) {
  return OverviewSectionViewModel(
    apiBaseUrl: 'http://127.0.0.1:8666',
    loadingHealth: loadingHealth,
    loadingHealthRoot: loadingHealthRoot,
    loadingPing: loadingPing,
    loadingVersion: loadingVersion,
    loadingReady: loadingReady,
    healthBody: healthBody,
    healthRootBody: healthRootBody,
    pingBody: pingBody,
    versionBody: versionBody,
    readyBody: readyBody,
  );
}

OverviewSectionViewCallbacks buildCallbacks({
  VoidCallback? onPingHealth = noop,
  VoidCallback? onPingHealthRoot = noop,
  VoidCallback? onPingPing = noop,
  VoidCallback? onPingVersion = noop,
  VoidCallback? onPingReady = noop,
}) {
  return OverviewSectionViewCallbacks(
    onPingHealth: onPingHealth,
    onPingHealthRoot: onPingHealthRoot,
    onPingPing: onPingPing,
    onPingVersion: onPingVersion,
    onPingReady: onPingReady,
  );
}

void main() {
  testWidgets('overview section view renders probe buttons and responses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewSectionView(
            model: buildModel(),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('API: http://127.0.0.1:8666'), findsOneWidget);
    expect(find.text('GET /api/v1/health'), findsOneWidget);
    expect(find.text('GET /health'), findsOneWidget);
    expect(find.text('GET /api/v1/ping'), findsOneWidget);
    expect(find.text('GET /api/v1/version'), findsOneWidget);
    expect(find.text('GET /api/v1/ready'), findsOneWidget);
    expect(find.text('health (v1): {"ok":true}'), findsOneWidget);
    expect(find.text('health (root): {"root":true}'), findsOneWidget);
    expect(find.text('ping: pong'), findsOneWidget);
    expect(find.text('version: {"version":"1.0.0"}'), findsOneWidget);
    expect(find.text('ready: {"ready":true}'), findsOneWidget);
  });

  testWidgets('overview section view disables buttons while loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewSectionView(
            model: buildModel(
              loadingHealth: true,
              loadingHealthRoot: true,
              loadingPing: true,
              loadingVersion: true,
              loadingReady: true,
            ),
            callbacks: buildCallbacks(
              onPingHealth: null,
              onPingHealthRoot: null,
              onPingPing: null,
              onPingVersion: null,
              onPingReady: null,
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widgetList<ButtonStyleButton>(find.byType(ButtonStyleButton))
          .every((button) => button.onPressed == null),
      isTrue,
    );
    expect(find.text('请求中…'), findsNWidgets(5));
  });

  testWidgets('overview section view forwards probe taps', (
    WidgetTester tester,
  ) async {
    var healthTapped = 0;
    var healthRootTapped = 0;
    var pingTapped = 0;
    var versionTapped = 0;
    var readyTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewSectionView(
            model: buildModel(),
            callbacks: buildCallbacks(
              onPingHealth: () => healthTapped++,
              onPingHealthRoot: () => healthRootTapped++,
              onPingPing: () => pingTapped++,
              onPingVersion: () => versionTapped++,
              onPingReady: () => readyTapped++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('GET /api/v1/health'));
    await tester.tap(find.text('GET /health'));
    await tester.tap(find.text('GET /api/v1/ping'));
    await tester.tap(find.text('GET /api/v1/version'));
    await tester.tap(find.text('GET /api/v1/ready'));
    await tester.pump();

    expect(healthTapped, 1);
    expect(healthRootTapped, 1);
    expect(pingTapped, 1);
    expect(versionTapped, 1);
    expect(readyTapped, 1);
  });
}
