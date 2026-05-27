import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
    await ProductDemoMode.instance.enable(guest: true);
  });

  tearDown(() async {
    ProductDemoTour.instance.stop();
    await ProductDemoMode.instance.disable();
  });

  test('enter does not rewind when tour already engaged past step 0', () {
    final tour = ProductDemoTour.instance;
    tour.enter(openFirstStop: false);
    tour.debugPrimeTourStep(index: 4, lockedStepIndex: 4);

    tour.enter(openFirstStop: false, resetToFirstStop: true);

    expect(tour.stepIndex, 4);
    expect(tour.isEngaged, isTrue);
  });
}
