import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    ProductDemoTour.instance.enter(openFirstStop: true);
  });

  tearDown(() async {
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
  });

  Future<void> pumpCoach(WidgetTester tester, Size size) async {
    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: size,
        child: ProductDemoCoachOverlay(onExit: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Positioned findCoachPositioned(WidgetTester tester) {
    final positioned = tester.widgetList<Positioned>(
      find.descendant(
        of: find.byType(ProductDemoCoachOverlay),
        matching: find.byType(Positioned),
      ),
    );
    return positioned.firstWhere(
      (p) => p.width != null && p.right != null && p.bottom != null,
    );
  }

  testWidgets('coach card docks bottom-right with glass panel', (tester) async {
    await pumpCoach(tester, const Size(1280, 800));

    final dock = findCoachPositioned(tester);
    expect(dock.right, 16);
    expect(dock.bottom, greaterThanOrEqualTo(16));
    expect(dock.left, isNull);
    expect(dock.top, isNull);
    expect(dock.width, lessThanOrEqualTo(360));

    expect(find.byType(BackdropFilter), findsOneWidget);
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.filter, isA<ImageFilter>());

    final decorated = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(DecoratedBox),
      ),
    );
    final panelColor =
        (decorated.decoration as BoxDecoration).color!;
    expect(panelColor.a, lessThan(0.45));

    expect(find.byKey(ProductDemoCoachKeys.tourNext), findsOneWidget);
    expect(find.byKey(ProductDemoCoachKeys.tourToggleDetails), findsOneWidget);
  });

  testWidgets('toggle details collapses and expands guide body', (tester) async {
    await pumpCoach(tester, const Size(1280, 800));

    expect(find.text('你要完成'), findsOneWidget);

    await tester.tap(find.byKey(ProductDemoCoachKeys.tourToggleDetails));
    await tester.pumpAndSettle();
    expect(find.text('你要完成'), findsNothing);

    await tester.tap(find.byKey(ProductDemoCoachKeys.tourToggleDetails));
    await tester.pumpAndSettle();
    expect(find.text('你要完成'), findsOneWidget);
  });

  testWidgets('coach card stays bottom-right on narrow viewport', (tester) async {
    await pumpCoach(tester, const Size(375, 812));

    final dock = findCoachPositioned(tester);
    expect(dock.right, 16);
    expect(dock.bottom, greaterThanOrEqualTo(16));
    expect(dock.width, lessThanOrEqualTo(375 - 32));
  });
}
