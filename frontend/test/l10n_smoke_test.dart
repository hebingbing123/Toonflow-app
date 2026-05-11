import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('AppLocalizations zh shows Chinese section title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.localeSectionTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('界面语言'), findsOneWidget);
  });

  testWidgets('AppLocalizations zh workspace mode title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.workspaceModeTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('工作区模式'), findsOneWidget);
  });

  testWidgets('AppLocalizations zh notifications center title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.notificationsCenterTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('通知中心'), findsOneWidget);
  });

  testWidgets('AppLocalizations zh product nav section title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.productNavSectionTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('产品导航'), findsOneWidget);
  });

  testWidgets('AppLocalizations zh platform config section title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.platformConfigSectionTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('平台配置'), findsOneWidget);
  });

  testWidgets('AppLocalizations zh risky prefs summary title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.riskyPrefsSummaryDialogTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已静默的高风险确认'), findsOneWidget);
  });

  testWidgets('AppLocalizations en risky prefs long tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: Text(l10n.riskyPrefsTooltipSameAsMainPanelHeaders),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Local client preferences'),
      findsOneWidget,
    );
  });

  testWidgets('AppLocalizations en notifications center title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.notificationsCenterTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('AppLocalizations zh projects list title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.projectsListTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('项目列表'), findsOneWidget);
  });

  testWidgets('AppLocalizations en shows English section title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Scaffold(body: Text(l10n.localeSectionTitle));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Display language'), findsOneWidget);
  });
}
