import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/demo/product_demo_coach_keys.dart';
import 'package:openflow_app/demo/product_demo_coach_overlay.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/studio_golden_app.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
    await ProductDemoMode.instance.enable(guest: true);
    ProductDemoTour.instance.enter(openFirstStop: false);
  });

  tearDown(() async {
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
  });

  testWidgets('coach overlay exposes automation keys', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: const Size(1280, 800),
        child: Scaffold(
          body: ProductDemoCoachOverlay(onExit: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ProductDemoCoachKeys.tourNext), findsOneWidget);
    expect(find.byKey(ProductDemoCoachKeys.tourAutoplay), findsOneWidget);
    expect(find.byKey(ProductDemoCoachKeys.tourPrevious), findsOneWidget);
    expect(find.byKey(ProductDemoCoachKeys.tourExit), findsOneWidget);
  });

  test('startAutoplay advances after dwell and survives non-interrupt enter',
      () async {
    final tour = ProductDemoTour.instance;
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
    tour.configure(router);
    final shortStops = <ProductDemoTourStop>[
      const ProductDemoTourStop(
        location: '/',
        titleZh: 'a',
        titleEn: 'a',
        guideZh: 'a',
        guideEn: 'a',
        dwell: Duration(milliseconds: 30),
      ),
      const ProductDemoTourStop(
        location: '/projects/7/script',
        titleZh: 'b',
        titleEn: 'b',
        guideZh: 'b',
        guideEn: 'b',
        dwell: Duration(milliseconds: 30),
      ),
    ];
    tour.enter(stops: shortStops, openFirstStop: false);
    tour.startAutoplay(router: router);
    expect(tour.isAutoplaying, isTrue);
    tour.enter(
      stops: shortStops,
      openFirstStop: false,
      interruptAutoplay: false,
      resetToFirstStop: false,
    );
    expect(tour.isAutoplaying, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(tour.stepIndex, 1);
    tour.stopAutoplay();
  });

  test('later goToNext wins over in-flight enter navigation to step 0', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tour = ProductDemoTour.instance;
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
    tour.configure(router);
    tour.enter(openFirstStop: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await tour.goToNext();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(tour.stepIndex, 1);
    tour.stopAutoplay();
  });

  test('stale enter navigation does not rewind route after goToNext', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tour = ProductDemoTour.instance;
    final navigated = <String>[];
    final router = GoRouter(
      initialLocation: '/projects/7/script',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
    tour.configure(
      router,
      navigateStop: (location) async {
        navigated.add(location);
        if (location == '/') {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      },
    );
    tour.enter(openFirstStop: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await tour.goToNext();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(tour.stepIndex, 1);
    expect(navigated, isNotEmpty);
    expect(navigated.last, contains('/script'));
    tour.stopAutoplay();
  });

  test('goToNext advances step index when router is configured', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tour = ProductDemoTour.instance;
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/projects/:projectNumericId/:stepSlug',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );
    tour.configure(router);
    tour.enter(openFirstStop: false);
    expect(tour.stepIndex, 0);
    await tour.goToNext();
    expect(tour.stepIndex, 1);
  });
}
