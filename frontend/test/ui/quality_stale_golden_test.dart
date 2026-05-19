import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_freshness_banner.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

import '../support/ui_gallery_capture.dart';

void main() {
  testWidgets('quality_stale golden', (tester) async {
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
              snapshotRowCount: 4,
              sourceReviewCount: 2,
              sourceUsageCount: 1,
              sourceMaxReviewCreatedAt: null,
              sourceMaxUsageCreatedAt: null,
              ageSeconds: 300,
              stale: true,
              staleReason: 'test',
              refreshMode: 'read',
            ),
            onRefresh: () {},
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(StudioFreshnessBanner),
      matchesGoldenFile(goldenPathForScenario('quality_stale')),
    );
  });
}
