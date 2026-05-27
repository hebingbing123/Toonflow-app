import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/config.dart';
import 'package:openflow_app/demo/product_demo_coach_overlay.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/demo/product_demo_coach_keys.dart';
import 'package:openflow_app/demo/product_demo_mode.dart';
import 'package:openflow_app/demo/product_demo_tour.dart';
import 'package:openflow_app/demo/product_demo_tour_shell_navigator.dart';
import 'package:openflow_app/design_system/components/studio_onboarding_coach.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';
import 'package:openflow_app/locale/app_locale_notifier.dart';
import 'package:openflow_app/native_bridge/native_bridge_bootstrap.dart';
import 'package:openflow_app/product_shell/studio_app.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One captured step while running demo-tour E2E (printed for human-readable logs).
class DemoTourStepReport {
  const DemoTourStepReport({
    required this.index,
    required this.location,
    required this.title,
    required this.engaged,
    required this.isAutoplaying,
    required this.hasCoachOverlay,
    required this.hasNextButton,
    required this.hasStepCounter,
    required this.hasGuideBody,
    required this.mode,
  });

  final int index;
  final String location;
  final String title;
  final bool engaged;
  final bool isAutoplaying;
  final bool hasCoachOverlay;
  final bool hasNextButton;
  final bool hasStepCounter;
  final bool hasGuideBody;
  final String mode;

  @override
  String toString() =>
      '[$mode step ${index + 1}] title=$title location=$location '
      'engaged=$engaged autoplay=$isAutoplaying '
      'overlay=$hasCoachOverlay next=$hasNextButton counter=$hasStepCounter body=$hasGuideBody';

  Map<String, Object?> toJson() => <String, Object?>{
        'index': index,
        'location': location,
        'title': title,
        'engaged': engaged,
        'isAutoplaying': isAutoplaying,
        'hasCoachOverlay': hasCoachOverlay,
        'hasNextButton': hasNextButton,
        'hasStepCounter': hasStepCounter,
        'hasGuideBody': hasGuideBody,
        'mode': mode,
      };
}

List<String> productDemoTourExpectedLocations() {
  return ProductDemoTour.buildDefaultStops()
      .map((stop) => stop.location)
      .toList(growable: false);
}

Future<void> ensureDemoTourTestEnvironment() async {
  configureGoogleFontsRuntime();
  try {
    Supabase.instance.client;
  } catch (_) {
    await Supabase.initialize(
      url: effectiveSupabaseUrl,
      anonKey: effectiveSupabaseAnonKey,
    );
  }
  await NativeBridgeBootstrap.instance.ensureStarted();
  await AppLocaleNotifier.instance.load();
  await AppLocaleNotifier.instance.setLocaleCode('en');
  await StudioOnboardingCoach.markSeen();
  ProductDemoMode.instance.disable();
  ProductDemoTour.instance.stop();
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 200),
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Future<void> waitForDemoTourStep(
  WidgetTester tester, {
  required int stepIndex,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final stops = ProductDemoTour.buildDefaultStops();
  final expectedLocation = stops[stepIndex].location;
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    final tour = ProductDemoTour.instance;
    if (!tour.isEngaged || tour.stepIndex != stepIndex) {
      continue;
    }
    final stop = tour.currentStop;
    if (stop != null && stop.location == expectedLocation) {
      return;
    }
  }
  fail(
    'Timed out waiting for demo tour step $stepIndex '
    '(location=$expectedLocation, index=${ProductDemoTour.instance.stepIndex}, '
    'engaged=${ProductDemoTour.instance.isEngaged})',
  );
}

Future<void> settleAfterTourNavigation(WidgetTester tester) async {
  const navWait = Duration(milliseconds: 5500);
  final slices = navWait.inMilliseconds ~/ 200;
  for (var i = 0; i < slices; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

DemoTourStepReport captureDemoTourStep(
  WidgetTester tester, {
  required int stepIndex,
  required String mode,
}) {
  final tour = ProductDemoTour.instance;
  final stop = tour.currentStop;
  final title = tour.currentGuideTitle ?? '';
  final body = tour.currentGuideBody ?? '';
  return DemoTourStepReport(
    index: stepIndex,
    location: stop?.location ?? '',
    title: title,
    engaged: tour.isEngaged,
    isAutoplaying: tour.isAutoplaying,
    hasCoachOverlay: find.byType(ProductDemoCoachOverlay).evaluate().isNotEmpty,
    hasNextButton: find.byKey(ProductDemoCoachKeys.tourNext).evaluate().isNotEmpty,
    hasStepCounter: find
        .textContaining('Step ${stepIndex + 1} of ${tour.stepCount}')
        .evaluate()
        .isNotEmpty,
    hasGuideBody:
        body.isNotEmpty && find.textContaining(body).evaluate().isNotEmpty,
    mode: mode,
  );
}

void logDemoTourReports(String heading, List<DemoTourStepReport> reports) {
  // ignore: avoid_print
  print('\n=== $heading (${reports.length} steps) ===');
  for (final report in reports) {
    // ignore: avoid_print
    print(report);
  }
  // ignore: avoid_print
  print('=== end $heading ===\n');
}

void assertFullCoachCardAtStep(
  WidgetTester tester, {
  required int stepIndex,
  required bool autoplay,
}) {
  final tour = ProductDemoTour.instance;
  expect(tour.isEngaged, isTrue);
  expect(tour.stepIndex, stepIndex);
  final next = find.byKey(ProductDemoCoachKeys.tourNext);
  expect(next, findsOneWidget);
  expect(find.byType(ProductDemoCoachOverlay), findsOneWidget);

  final l10n = AppLocalizations.of(tester.element(next))!;
  expect(
    find.text(l10n.productDemoGuideStepCounter(stepIndex + 1, tour.stepCount)),
    findsOneWidget,
  );
  final title = tour.currentGuideTitle;
  if (title != null && title.isNotEmpty) {
    expect(find.text(title), findsWidgets);
  }
  final sections = tour.currentGuideSections;
  if (sections != null) {
    expect(find.text(l10n.productDemoGuideSectionGoal), findsWidgets);
    expect(
      find.textContaining(sections.goalForLocale(tour.languageCode)),
      findsWidgets,
    );
  } else {
    final body = tour.currentGuideBody;
    if (body != null && body.isNotEmpty) {
      expect(find.textContaining(body), findsWidgets);
    }
  }
  if (autoplay) {
    expect(tour.isAutoplaying, isTrue);
    expect(find.textContaining(l10n.productDemoAutoplayPause), findsWidgets);
  } else {
    expect(tour.isAutoplaying, isFalse);
    expect(find.textContaining(l10n.productDemoGuideStartAutoplay), findsWidgets);
  }
}

void assertNoDemoStudioFailureBanner(WidgetTester tester) {
  expect(find.textContaining('generation tasks failed'), findsNothing);
  expect(find.textContaining('部分生成任务失败'), findsNothing);
}

Future<void> assertHelpHubDemoDocsLoaded(WidgetTester tester) async {
  expect(find.textContaining('Failed to fetch'), findsNothing);
  final doc = find.textContaining('Getting started');
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (doc.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(find.textContaining('Failed to fetch'), findsNothing);
}

Future<void> bootstrapGuestDemoTourApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(const StudioProductApp());
  await pumpUntilFound(
    tester,
    find.byKey(ProductDemoCoachKeys.exploreGuestLogin),
    timeout: const Duration(seconds: 60),
  );
  await tester.tap(find.byKey(ProductDemoCoachKeys.exploreGuestLogin));
  await pumpUntilFound(
    tester,
    find.byKey(ProductDemoCoachKeys.tourNext),
    timeout: const Duration(seconds: 45),
  );
  await waitForDemoTourStep(tester, stepIndex: 0);
  expect(ProductDemoTour.instance.isEngaged, isTrue);
  expect(ProductDemoTour.instance.isAutoplaying, isFalse);
}

Future<void> tapDemoTourNext(WidgetTester tester) async {
  final next = find.byKey(ProductDemoCoachKeys.tourNext);
  await tester.ensureVisible(next);
  await tester.tap(next);
  await settleAfterTourNavigation(tester);
}

/// Manual mode: full tour driven only by tapping [ProductDemoCoachKeys.tourNext].
Future<List<DemoTourStepReport>> runManualDemoTourBySimulatedClicks(
  WidgetTester tester,
) async {
  final stops = ProductDemoTour.buildDefaultStops();
  final reports = <DemoTourStepReport>[];

  for (var i = 0; i < stops.length; i++) {
    await waitForDemoTourStep(tester, stepIndex: i);
    assertFullCoachCardAtStep(tester, stepIndex: i, autoplay: false);
    if (i >= 1 && i <= StudioStep.sopSteps.length) {
      assertNoDemoStudioFailureBanner(tester);
    }
    reports.add(captureDemoTourStep(tester, stepIndex: i, mode: 'manual'));
    if (i < stops.length - 1) {
      await tapDemoTourNext(tester);
    }
  }

  await assertHelpHubDemoDocsLoaded(tester);
  expect(ProductDemoTour.instance.currentStop?.location, stops.last.location);
  return reports;
}

/// Auto mode: start autoplay and pump through all beats; assert full card on changes.
Future<List<DemoTourStepReport>> runAutoplayDemoTour(WidgetTester tester) async {
  final router = ProductDemoTourShellNavigator.instance.router;
  expect(router, isNotNull);
  ProductDemoTour.instance.startAutoplay(languageCode: 'en', router: router);

  final stops = ProductDemoTour.buildDefaultStops();
  final reports = <DemoTourStepReport>[];
  final seen = <int>{};
  final deadline = DateTime.now().add(const Duration(minutes: 4));

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 350));
    final index = ProductDemoTour.instance.stepIndex;
    if (seen.contains(index)) {
      if (index >= stops.length - 1) {
        break;
      }
      continue;
    }
    seen.add(index);
    await waitForDemoTourStep(tester, stepIndex: index);
    assertFullCoachCardAtStep(tester, stepIndex: index, autoplay: true);
    if (index >= 1 && index <= StudioStep.sopSteps.length) {
      assertNoDemoStudioFailureBanner(tester);
    }
    reports.add(captureDemoTourStep(tester, stepIndex: index, mode: 'autoplay'));
    if (index >= stops.length - 1) {
      break;
    }
  }

  for (var i = 0; i < stops.length; i++) {
    expect(
      seen.contains(i),
      isTrue,
      reason: 'autoplay skipped step $i (saw: ${seen.toList()..sort()})',
    );
  }
  expect(ProductDemoTour.instance.stepIndex, stops.length - 1);
  await assertHelpHubDemoDocsLoaded(tester);
  ProductDemoTour.instance.stop();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  return reports;
}
