import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_conflict_banner.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('conflict banner uses localized retry and dismiss', (
    WidgetTester tester,
  ) async {
    var refreshed = false;
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioConflictBanner(
            message: '数据已在别处更新，请刷新后继续。',
            onRefresh: () => refreshed = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(refreshed, isTrue);

    await tester.tap(find.byTooltip('关闭'));
    expect(dismissed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
