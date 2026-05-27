import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';

import 'support/product_demo_tour_e2e_support.dart';

/// Product demo tour — manual (simulated Next taps) and autoplay on desktop.
///
/// ```bash
/// cd frontend && flutter test integration_test/product_demo_tour_modes_test.dart \
///   -d macos --dart-define-from-file=dart_defines.dev.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await ensureDemoTourTestEnvironment();
  });

  tearDown(() {
    ProductDemoTour.instance.stop();
    ProductDemoMode.instance.disable();
  });

  testWidgets('manual mode — full tour via simulated Next taps', (
    tester,
  ) async {
    await bootstrapGuestDemoTourApp(tester);
    final reports = await runManualDemoTourBySimulatedClicks(tester);
    logDemoTourReports('MANUAL (simulated clicks)', reports);

    expect(reports.length, kProductDemoTourBeatCount);
    for (final report in reports) {
      expect(report.engaged, isTrue);
      expect(report.isAutoplaying, isFalse);
      expect(report.hasNextButton, isTrue);
      expect(report.hasCoachOverlay, isTrue);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('autoplay mode — full coach card on each step', (
    tester,
  ) async {
    await bootstrapGuestDemoTourApp(tester);
    final reports = await runAutoplayDemoTour(tester);
    logDemoTourReports('AUTOPLAY', reports);

    expect(reports.length, kProductDemoTourBeatCount);
    for (final report in reports) {
      expect(report.engaged, isTrue);
      expect(report.isAutoplaying, isTrue);
      expect(report.hasNextButton, isTrue);
      expect(report.hasCoachOverlay, isTrue);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
