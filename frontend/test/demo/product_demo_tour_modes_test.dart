import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/config.dart';
import 'package:openflow_app/demo/product_demo_coach_keys.dart';
import 'package:openflow_app/demo/product_demo_coach_overlay.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';
import 'package:openflow_app/demo/product_demo_tour_shell_navigator.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../integration_test/support/product_demo_tour_e2e_support.dart';

/// Fast VM tests for manual vs autoplay coach UX (no macOS device required).
///
/// Full shell navigation is covered by
/// `integration_test/product_demo_tour_modes_test.dart`.
///
/// ```bash
/// cd frontend && flutter test test/demo/product_demo_tour_modes_test.dart \
///   --dart-define-from-file=dart_defines.dev.json
/// ```
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: effectiveSupabaseUrl,
        anonKey: effectiveSupabaseAnonKey,
      );
    }
    await ProductDemoMode.instance.disable();
    ProductDemoTour.instance.stop();
  });

  tearDown(() async {
    ProductDemoTour.instance.stopAutoplay();
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
  });

  Future<void> pumpCoachHarness(WidgetTester tester) async {
    final shellNav = ShellNavigationController();
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
    ProductDemoTourShellNavigator.instance.attach(
      router: router,
      shellNavigation: shellNav,
    );
    await ProductDemoMode.instance.enable(guest: true);
    ProductDemoTour.instance.configure(router);
    ProductDemoTour.instance.enter(languageCode: 'en', openFirstStop: true);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: ProductDemoCoachOverlay(
              goRouter: router,
              onExit: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('manual — each Next tap advances index and keeps full coach card',
      (tester) async {
    await pumpCoachHarness(tester);
    final stops = ProductDemoTour.buildDefaultStops();
    final reports = <DemoTourStepReport>[];

    for (var i = 0; i < stops.length; i++) {
      expect(ProductDemoTour.instance.stepIndex, i);
      assertFullCoachCardAtStep(tester, stepIndex: i, autoplay: false);
      reports.add(captureDemoTourStep(tester, stepIndex: i, mode: 'manual-vm'));
      if (i < stops.length - 1) {
        await tester.tap(find.byKey(ProductDemoCoachKeys.tourNext));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    logDemoTourReports('MANUAL VM (tap Next)', reports);
    expect(reports.length, kProductDemoTourBeatCount);
    expect(reports.every((r) => r.hasNextButton), isTrue);
    expect(reports.every((r) => !r.isAutoplaying), isTrue);

    await _drainTourTimers(tester);
  });

  testWidgets('autoplay — full coach card visible while autoplaying', (
    tester,
  ) async {
    await pumpCoachHarness(tester);
    final router = ProductDemoTourShellNavigator.instance.router!;
    ProductDemoTour.instance.startAutoplay(languageCode: 'en', router: router);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ProductDemoTour.instance.isAutoplaying, isTrue);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(ProductDemoTour.instance.isAutoplaying, isTrue);
    expect(
      find.text(l10n.productDemoGuideStepCounter(1, kProductDemoTourBeatCount)),
      findsOneWidget,
    );
    expect(find.byKey(ProductDemoCoachKeys.tourNext), findsOneWidget);
    expect(find.byType(ProductDemoCoachOverlay), findsOneWidget);

    await _drainTourTimers(tester);
  });
}

Future<void> _drainTourTimers(WidgetTester tester) async {
  ProductDemoTour.instance.stopAutoplay();
  ProductDemoTour.instance.stop();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
