import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/config.dart';
import 'package:openflow_app/design_system/components/openflow_brand.dart';
import 'package:openflow_app/design_system/components/studio_onboarding_coach.dart';
import 'package:openflow_app/locale/app_locale_notifier.dart';
import 'package:openflow_app/product_shell/studio_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared harness for real-stack product shell PNG galleries.
class RealProductShellGalleryHarness {
  RealProductShellGalleryHarness(
    this.tester, {
    String? outputDir,
    this.screenshotSize = const Size(1280, 900),
  }) : _outputDirOverride = outputDir;

  final WidgetTester tester;
  final Size screenshotSize;
  final String? _outputDirOverride;
  late final String outputDir;
  final GlobalKey repaintKey = GlobalKey();
  var _shotIndex = 0;

  /// Uses the app container temp dir (same as compact gallery). Host runner copies PNGs
  /// to `frontend/build/e2e_gallery/` using the `E2E_GALLERY_DIR=` line printed at end of test.
  static String resolveDefaultGalleryOutputDir() {
    const fromEnv = String.fromEnvironment('OPENFLOW_E2E_GALLERY_DIR');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return '${Directory.systemTemp.path}/openflow_e2e_gallery';
  }

  static Future<void> ensureSupabaseReady() async {
    try {
      Supabase.instance.client;
      return;
    } catch (_) {}
    await Supabase.initialize(
      url: effectiveSupabaseUrl,
      anonKey: effectiveSupabaseAnonKey,
    );
  }

  Future<void> bootstrap() async {
    outputDir = _outputDirOverride ?? resolveDefaultGalleryOutputDir();
    final out = Directory(outputDir);
    if (out.existsSync()) {
      for (final entry in out.listSync()) {
        if (entry is File && entry.path.endsWith('.png')) {
          entry.deleteSync();
        }
      }
    }
    await ensureSupabaseReady();
    await AppLocaleNotifier.instance.load();
    await AppLocaleNotifier.instance.setLocaleCode('zh');
    await tester.binding.setSurfaceSize(screenshotSize);
    await StudioOnboardingCoach.markSeen();
    await Supabase.instance.client.auth.signOut();
    await Directory(outputDir).create(recursive: true);
    await tester.pumpWidget(
      RepaintBoundary(key: repaintKey, child: const StudioProductApp()),
    );
  }

  Future<void> pumpFrames({
    int count = 12,
    Duration step = const Duration(milliseconds: 250),
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<void> waitFor(
    Finder finder, {
    int maxTicks = 48,
    Duration step = const Duration(milliseconds: 250),
  }) async {
    for (var i = 0; i < maxTicks; i++) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    expect(finder, findsWidgets);
  }

  Future<void> capture(String scenarioId) async {
    _shotIndex += 1;
    final index = _shotIndex.toString().padLeft(2, '0');
    final name = 'regular_${index}_$scenarioId';
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outputDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  }

  Future<void> login() async {
    await waitFor(find.text('登录'));
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
    await waitFor(find.byTooltip('通知'));
    await pumpFrames(count: 24);
  }

  Future<void> tapTooltip(String tooltip) async {
    final finder = find.byTooltip(tooltip);
    await tester.ensureVisible(finder);
    await tester.tap(finder, warnIfMissed: false);
    await pumpFrames(count: 16);
  }

  /// Triggers `NotificationsController.refresh()` when the pane shows the reload control.
  Future<void> refreshNotificationsIfPossible() async {
    final refresh = find.byIcon(Icons.refresh);
    if (refresh.evaluate().isEmpty) {
      return;
    }
    await tester.tap(refresh.first, warnIfMissed: false);
    await pumpFrames(count: 28);
  }

  Future<void> openMoreMenu() async {
    await tapTooltip('更多');
    await waitFor(find.text('多平台分发'));
  }

  Future<void> closeOverlay() async {
    if (find.byType(BackButton).evaluate().isNotEmpty) {
      await tester.tap(find.byType(BackButton).first);
      await pumpFrames();
      return;
    }
    if (find.byIcon(Icons.close).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.close).first, warnIfMissed: false);
      await pumpFrames();
      return;
    }
    // Dismiss modal bottom sheet.
    await tester.tapAt(const Offset(12, 12));
    await pumpFrames();
  }

  Future<void> goProjectsHome() async {
    if (find.byType(ModalBarrier).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(8, 8));
      await pumpFrames();
    }
    for (var round = 0; round < 4; round++) {
      if (find.text('新建项目').evaluate().isNotEmpty ||
          find.text('你的项目').evaluate().isNotEmpty) {
        return;
      }
      if (find.byType(BackButton).evaluate().isNotEmpty) {
        await tester.tap(find.byType(BackButton).first, warnIfMissed: false);
        await pumpFrames(count: 12);
        continue;
      }
      final brand = find.byType(OpenFlowBrandMark);
      if (brand.evaluate().isNotEmpty) {
        await tester.tap(brand.first, warnIfMissed: false);
        await pumpFrames(count: 16);
      }
      final pipelineProjects = find.text('项目');
      if (pipelineProjects.evaluate().isNotEmpty) {
        await tester.tap(pipelineProjects.first, warnIfMissed: false);
        await pumpFrames(count: 16);
      }
    }
  }

  Future<void> openSettingsHub() async {
    await tapTooltip('账户与设置');
    await waitFor(find.text('设置'));
  }

  Future<void> openSettingsTab(String tabLabel) async {
    await openSettingsHub();
    await tester.tap(find.text(tabLabel));
    await pumpFrames(count: 16);
  }

  Future<void> closeMoreMenuIfOpen() async {
    if (find.byType(BottomSheet).evaluate().isEmpty) {
      return;
    }
    await tester.tapAt(const Offset(12, 12));
    await pumpFrames();
  }

  Finder _moreMenuItem(String label) {
    final sheet = find.byType(BottomSheet);
    if (sheet.evaluate().isEmpty) {
      return find.text(label);
    }
    return find.descendant(of: sheet, matching: find.text(label));
  }

  Future<void> selectMoreMenuItem(
    String label, {
    bool menuAlreadyOpen = false,
  }) async {
    if (!menuAlreadyOpen) {
      await openMoreMenu();
    }
    final menuScroll = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    for (var attempt = 0; attempt < 10; attempt++) {
      final matches = _moreMenuItem(label);
      if (matches.evaluate().isNotEmpty) {
        await tester.tap(matches.first, warnIfMissed: false);
        await pumpFrames(count: 32);
        return;
      }
      if (menuScroll.evaluate().isEmpty) {
        break;
      }
      await tester.drag(menuScroll.first, const Offset(0, -220));
      await pumpFrames(count: 6);
    }
    expect(_moreMenuItem(label), findsWidgets, reason: 'Missing «更多» item: $label');
  }

  /// Returns false when the pane is absent from «更多» (e.g. platform toggles).
  Future<bool> trySelectMoreMenuItem(String label) async {
    try {
      await selectMoreMenuItem(label);
      return true;
    } catch (_) {
      await closeMoreMenuIfOpen();
      await goProjectsHome();
      return false;
    }
  }

  Future<void> tapPipelineChip(String label) async {
    await goProjectsHome();
    final chip = find.text(label);
    await tester.scrollUntilVisible(
      chip,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(chip);
    await pumpFrames(count: 24);
  }

  int get shotCount => _shotIndex;

  List<File> listCapturedPngs() {
    final dir = Directory(outputDir);
    if (!dir.existsSync()) {
      return <File>[];
    }
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }
}
