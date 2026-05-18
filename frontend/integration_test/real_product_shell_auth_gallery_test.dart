import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/config.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';
import 'package:openflow_app/design_system/components/studio_onboarding_coach.dart';
import 'package:openflow_app/locale/app_locale_notifier.dart';
import 'package:openflow_app/product_shell/studio_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  const screenshotSize = Size(1280, 900);
  final outputDir =
      '${Directory.systemTemp.path}/openflow_desktop_product_shell_real';

  Future<void> ensureSupabaseReady() async {
    try {
      Supabase.instance.client;
      return;
    } catch (_) {}
    await Supabase.initialize(
      url: effectiveSupabaseUrl,
      anonKey: effectiveSupabaseAnonKey,
    );
  }

  Future<void> pumpFrames(
    WidgetTester tester, {
    int count = 12,
    Duration step = const Duration(milliseconds: 250),
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int maxTicks = 40,
  }) async {
    for (var i = 0; i < maxTicks; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    expect(finder, findsWidgets);
  }

  Future<void> captureShot(
    WidgetTester tester, {
    required GlobalKey repaintKey,
    required String name,
  }) async {
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outputDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  }

  testWidgets('capture real product shell desktop flow', (
    WidgetTester tester,
  ) async {
    await ensureSupabaseReady();
    await AppLocaleNotifier.instance.load();
    await AppLocaleNotifier.instance.setLocaleCode('zh');
    await tester.binding.setSurfaceSize(screenshotSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await StudioOnboardingCoach.markSeen();
    await Supabase.instance.client.auth.signOut();

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(key: repaintKey, child: const StudioProductApp()),
    );
    await waitFor(tester, find.text('登录'));
    await captureShot(tester, repaintKey: repaintKey, name: 'regular_01_login');

    await tester.enterText(
      find.byKey(const Key('product-auth-email')),
      kDevAdminEmail,
    );
    await tester.enterText(
      find.byKey(const Key('product-auth-password')),
      kDevAdminPassword,
    );
    final submitFinder = find.byKey(const Key('product-auth-submit'));
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await waitFor(tester, find.byTooltip('通知'));
    await pumpFrames(tester, count: 20);
    await captureShot(
      tester,
      repaintKey: repaintKey,
      name: 'regular_02_projects',
    );

    await tester.tap(find.byTooltip('通知'));
    await pumpFrames(tester);
    await captureShot(
      tester,
      repaintKey: repaintKey,
      name: 'regular_03_notifications',
    );

    await tester.tap(find.byTooltip('账户与设置'));
    await waitFor(tester, find.text('设置'));
    await pumpFrames(tester);
    await captureShot(
      tester,
      repaintKey: repaintKey,
      name: 'regular_04_account',
    );

    await tester.tap(find.byTooltip('更多'));
    await waitFor(tester, find.text('任务中心'));
    await captureShot(
      tester,
      repaintKey: repaintKey,
      name: 'regular_05_more_menu',
    );

    await tester.tap(find.text('任务中心'));
    await pumpFrames(tester, count: 20);
    await captureShot(tester, repaintKey: repaintKey, name: 'regular_06_tasks');

    await tester.tap(find.byTooltip('更多'));
    final complianceFinder = find.text('内容合规');
    await tester.scrollUntilVisible(
      complianceFinder,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(complianceFinder);
    await pumpFrames(tester, count: 20);
    await captureShot(
      tester,
      repaintKey: repaintKey,
      name: 'regular_07_content_compliance',
    );

    expect(
      File('$outputDir/regular_07_content_compliance.png').existsSync(),
      isTrue,
    );
  });
}
