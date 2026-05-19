import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_freshness_banner.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/quality_reviews/controller.dart';
import 'package:openflow_app/quality_reviews/section.dart';
import 'package:openflow_app/rust_api.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Wave-1 `quality_default` / stale banner — no raw STALE tokens in tree.
void main() {
  testWidgets('quality section uses freshness banner when stale', (
    WidgetTester tester,
  ) async {
    final controller = QualityReviewsController(
      accessTokenProvider: () => 'token',
      onErrorChanged: (_) {},
    );
    controller.qualityDashboardMeta = const QualityDashboardMeta(
      refreshedAt: null,
      snapshotRowCount: 0,
      sourceReviewCount: 0,
      sourceUsageCount: 0,
      sourceMaxReviewCreatedAt: null,
      sourceMaxUsageCreatedAt: null,
      ageSeconds: 120,
      stale: true,
      staleReason: null,
      refreshMode: 'read',
    );

    await tester.pumpWidget(
      _wrap(
        QualityReviewsSection(
          accessToken: 'token',
          controller: controller,
          initialProjectNumericId: 1,
          platformConfig: PlatformConfigToggleSetV1.defaults,
          studioPresentation: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudioFreshnessBanner), findsOneWidget);
    expect(find.textContaining('STALE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
