import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_en.dart';
import 'package:openflow_app/overview/section_view.dart';

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

Widget wrapWithEnL10n(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  final en = AppLocalizationsEn();

  testWidgets('overview section view renders probe buttons and responses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWithEnL10n(
        OverviewSectionView(
          model: buildModel(),
          callbacks: buildCallbacks(),
        ),
      ),
    );

    expect(find.text(en.workspaceDebugOverviewApiBase('http://127.0.0.1:8666')), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewButtonHealthV1), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewButtonHealthRoot), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewButtonPing), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewButtonVersion), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewButtonReady), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewHealthV1Line('{"ok":true}')), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewHealthRootLine('{"root":true}')), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewPingLine('pong')), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewVersionLine('{"version":"1.0.0"}')), findsOneWidget);
    expect(find.text(en.workspaceDebugOverviewReadyLine('{"ready":true}')), findsOneWidget);
  });

  testWidgets('overview section view disables buttons while loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWithEnL10n(
        OverviewSectionView(
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
    );

    expect(
      tester
          .widgetList<ButtonStyleButton>(find.byType(ButtonStyleButton))
          .every((button) => button.onPressed == null),
      isTrue,
    );
    expect(find.text(en.workspaceDebugOverviewProbeBusy), findsNWidgets(5));
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
      wrapWithEnL10n(
        OverviewSectionView(
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
    );

    await tester.tap(find.text(en.workspaceDebugOverviewButtonHealthV1));
    await tester.tap(find.text(en.workspaceDebugOverviewButtonHealthRoot));
    await tester.tap(find.text(en.workspaceDebugOverviewButtonPing));
    await tester.tap(find.text(en.workspaceDebugOverviewButtonVersion));
    await tester.tap(find.text(en.workspaceDebugOverviewButtonReady));
    await tester.pump();

    expect(healthTapped, 1);
    expect(healthRootTapped, 1);
    expect(pingTapped, 1);
    expect(versionTapped, 1);
    expect(readyTapped, 1);
  });
}
