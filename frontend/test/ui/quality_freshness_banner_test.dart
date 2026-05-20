import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_freshness_banner.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  testWidgets('StudioFreshnessBanner does not show raw STALE label', (
    tester,
  ) async {
    var refreshed = false;
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
          body: StudioFreshnessBanner(
            meta: const QualityDashboardMeta(
              refreshedAt: null,
              snapshotRowCount: 3,
              sourceReviewCount: 1,
              sourceUsageCount: 0,
              sourceMaxReviewCreatedAt: null,
              sourceMaxUsageCreatedAt: null,
              ageSeconds: 120,
              stale: true,
              staleReason: 'snapshot_older_than_source',
              refreshMode: 'read',
            ),
            onRefresh: () => refreshed = true,
          ),
        ),
      ),
    );

    expect(find.textContaining('STALE'), findsNothing);
    expect(find.textContaining('unknown_age'), findsNothing);
    expect(find.text('看板数据可能不是最新'), findsOneWidget);
    await tester.tap(find.text('刷新看板'));
    await tester.pump();
    expect(refreshed, isTrue);
  });
}
