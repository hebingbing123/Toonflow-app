import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';

import 'support/product_demo_tour_e2e_support.dart';

/// Desktop screenshots for each demo-tour beat (24 PNGs + report JSON).
///
/// ```bash
/// cd frontend && OPENFLOW_DEMO_TOUR_SCREENSHOT_DIR=../scratch/demo-tour-e2e-24-desktop \
///   flutter test integration_test/product_demo_tour_screenshot_test.dart -d macos \
///   --dart-define-from-file=dart_defines.dev.json
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Platform.environment['OPENFLOW_DEMO_TOUR_SCREENSHOT_DIR'] ??
      'build/demo-tour-screenshots';

  setUp(() async {
    await ensureDemoTourTestEnvironment();
  });

  tearDown(() {
    ProductDemoTour.instance.stop();
    ProductDemoMode.instance.disable();
  });

  testWidgets('capture 24 tour beats on macOS desktop', (tester) async {
    Directory(outDir).createSync(recursive: true);
    await bootstrapGuestDemoTourApp(tester);
    final stops = ProductDemoTour.buildDefaultStops();
    expect(stops.length, kProductDemoTourBeatCount);

    final reports = <DemoTourStepReport>[];

    for (var i = 0; i < stops.length; i++) {
      await waitForDemoTourStep(tester, stepIndex: i);
      await tester.pump(const Duration(milliseconds: 400));
      await binding.convertFlutterSurfaceToImage();
      final name = 'step-${(i + 1).toString().padLeft(2, '0')}';
      await binding.takeScreenshot(name);
      reports.add(captureDemoTourStep(tester, stepIndex: i, mode: 'screenshot'));
      final stop = ProductDemoTour.instance.currentStop;
      final reportPath = File('$outDir/$name.meta.txt');
      await reportPath.writeAsString(
        'title=${stop?.titleEn}\n'
        'location=${stop?.location}\n'
        'mainline=${stop?.mainlineStep}\n'
        'part=${stop?.mainlinePart}/${stop?.mainlinePartTotal}\n'
        '${reports.last}\n',
      );
      if (i < stops.length - 1) {
        await tapDemoTourNext(tester);
      }
    }

    logDemoTourReports('macOS screenshot tour', reports);
    await File('$outDir/tour-report.txt').writeAsString(
      reports.map((r) => r.toString()).join('\n'),
    );
    expect(reports.length, kProductDemoTourBeatCount);
    expect(reports.every((r) => r.hasCoachOverlay && r.hasNextButton), isTrue);
  });
}
