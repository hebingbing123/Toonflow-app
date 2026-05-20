import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';
import 'package:openflow_app/design_system/ix/studio_command_palette.dart';
import 'package:openflow_app/design_system/ix/studio_conflict_banner.dart';
import 'package:openflow_app/design_system/ix/studio_job_tray.dart';
import 'package:openflow_app/studio/job_center.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/quality_reviews/controller.dart';
import 'package:openflow_app/quality_reviews/section.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, child) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: child ?? const SizedBox(),
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('quality section shows localized freshness banner', (tester) async {
    final controller = QualityReviewsController(
      accessTokenProvider: () => 'token',
      onErrorChanged: (_) {},
    );
    controller.qualityDashboardMeta = const QualityDashboardMeta(
      refreshedAt: null,
      snapshotRowCount: 2,
      sourceReviewCount: 1,
      sourceUsageCount: 0,
      sourceMaxReviewCreatedAt: null,
      sourceMaxUsageCreatedAt: null,
      ageSeconds: 90,
      stale: true,
      staleReason: null,
      refreshMode: 'read',
    );
    controller.qualityStatsRows = const <QualityDashboardTargetStat>[];

    await tester.pumpWidget(
      wrap(
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

    expect(find.textContaining('STALE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('job tray pumps with seeded active job', (tester) async {
    StudioJobCenter.instance.clear();
    addTearDown(StudioJobCenter.instance.clear);
    StudioJobCenter.instance.upsert(
      const StudioJobSnapshot(
        jobId: 'smoke-job-1',
        status: 'queued',
        label: 'Smoke export',
      ),
    );

    await tester.pumpWidget(
      wrap(const StudioJobTray()),
    );
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflict banner refresh and dismiss pump cleanly', (tester) async {
    await tester.pumpWidget(
      wrap(
        StudioConflictBanner(
          message: '数据已在别处更新，请刷新后继续。',
          onRefresh: () {},
          onDismiss: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('command palette shortcuts pump without exception', (tester) async {
    await tester.pumpWidget(
      wrap(
        StudioCommandPaletteShortcuts(
          actions: const <StudioCommandAction>[],
          child: const Text('body'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
