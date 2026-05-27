// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/config.dart';
import 'package:openflow_app/design_system/components/openflow_brand.dart';
import 'package:openflow_app/design_system/components/studio_primary_button.dart';
import 'package:openflow_app/design_system/components/studio_onboarding_coach.dart';
import 'package:openflow_app/locale/app_locale_notifier.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/product_shell/studio_app.dart';
import 'package:openflow_app/product_shell/studio_shell_branches.dart';
import 'package:openflow_app/product_shell/studio_shell_navigation_scope.dart';
import 'package:openflow_app/shell/navigation_controller.dart';
import 'package:openflow_app/shell/studio_settings_hub_navigation.dart';
import 'package:openflow_app/rust_api.dart';
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
  var _interactionIndex = 0;
  final List<Map<String, String>> auditManifest = <Map<String, String>>[];
  String? lastSeedProjectName;
  int? lastSeedProjectNumericId;

  /// One frame (~16ms) — audit must not use 250ms pumps (adds hours per run).
  static const Duration auditPumpStep = Duration(milliseconds: 16);

  void _auditProgress(String step) {
    print(
      'E2E_AUDIT_STEP=$step at=${DateTime.now().toIso8601String()} '
      'routes=$_shotIndex interactions=$_interactionIndex',
    );
  }

  /// Uses the app container temp dir (same as compact gallery). Host runner copies PNGs
  /// to `frontend/build/e2e_gallery/` using the `E2E_GALLERY_DIR=` line printed at end of test.
  static String resolveDefaultGalleryOutputDir() {
    const fromEnv = String.fromEnvironment('OPENFLOW_E2E_GALLERY_DIR');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return '${Directory.systemTemp.path}/openflow_e2e_gallery';
  }

  /// macOS app-container temp (integration_test cannot write under repo `.codex/`).
  static String resolveAuditGalleryRoot() {
    const fromEnv = String.fromEnvironment('OPENFLOW_UI_UX_AUDIT_OUTPUT');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return '${Directory.systemTemp.path}/openflow_ui_ux_audit';
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
        if (entry is File &&
            (entry.path.endsWith('.png') || entry.path.endsWith('.json'))) {
          entry.deleteSync();
        }
      }
    }
    _shotIndex = 0;
    _interactionIndex = 0;
    auditManifest.clear();
    await ensureSupabaseReady();
    await AppLocaleNotifier.instance.load();
    await AppLocaleNotifier.instance.setLocaleCode('zh');
    await StudioOnboardingCoach.markSeen();
    if (Supabase.instance.client.auth.currentSession != null) {
      try {
        await Supabase.instance.client.auth.signOut().timeout(
          const Duration(seconds: 15),
        );
      } catch (_) {}
    }
    await Directory(outputDir).create(recursive: true);
    await tester.pumpWidget(
      RepaintBoundary(key: repaintKey, child: const StudioProductApp()),
    );
    await pumpFrames(count: 12);
  }

  Future<void> pumpFrames({
    int count = 12,
    Duration step = auditPumpStep,
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<void> waitFor(
    Finder finder, {
    int maxTicks = 48,
    Duration step = auditPumpStep,
  }) async {
    for (var i = 0; i < maxTicks; i++) {
      await tester.pump(step);
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    expect(finder, findsWidgets);
  }

  Future<File> _writePng(String prefix, String scenarioId, String kind) async {
    await pumpFrames(count: 4);
    final index = (kind == 'interaction' ? ++_interactionIndex : ++_shotIndex)
        .toString()
        .padLeft(2, '0');
    final name = '${prefix}_${index}_$scenarioId';
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outputDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    auditManifest.add(<String, String>{
      'kind': kind,
      'id': scenarioId,
      'file': '$name.png',
    });
    return file;
  }

  Future<void> capture(String scenarioId) async {
    _auditProgress('capture_route_$scenarioId');
    await _writePng('regular', scenarioId, 'route');
  }

  /// Dialog / sheet / menu / expanded panel — not counted as primary routes.
  Future<bool> captureInteraction(
    String scenarioId, {
    bool requireOverlay = false,
  }) async {
    _auditProgress('capture_interaction_$scenarioId');
    await pumpFrames(count: 8);
    if (requireOverlay && !hasBlockingOverlay) {
      return false;
    }
    await _writePng('interaction', scenarioId, 'interaction');
    return true;
  }

  Future<void> writeAuditManifest() async {
    final manifest = <String, dynamic>{
      'outputDir': outputDir,
      'viewport':
          '${screenshotSize.width.toInt()}x${screenshotSize.height.toInt()}',
      'routeCount': _shotIndex,
      'interactionCount': _interactionIndex,
      'captures': auditManifest,
    };
    final file = File('$outputDir/audit_manifest.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );
    print('E2E_AUDIT_MANIFEST=$outputDir/audit_manifest.json');
  }

  Future<void> waitForShellReady({int maxTicks = 120}) async {
    final candidates = <Finder>[
      find.byKey(const Key('studio-app-bar-notifications')),
      find.text('你的项目'),
      find.text('新建项目'),
      find.text('New project'),
      find.byKey(const ValueKey<String>('studio-shell-root')),
    ];
    for (var i = 0; i < maxTicks; i++) {
      await pumpFrames(count: 1);
      for (final finder in candidates) {
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
    }
    expect(find.text('新建项目'), findsWidgets);
  }

  bool get _isShellAuthenticated =>
      find.text('你的项目').evaluate().isNotEmpty ||
      find.text('新建项目').evaluate().isNotEmpty ||
      find.text('New project').evaluate().isNotEmpty;

  Future<void> _waitForLoginScreenOrShell({int maxTicks = 120}) async {
    for (var i = 0; i < maxTicks; i++) {
      await tester.pump(auditPumpStep);
      if (_isShellAuthenticated) {
        return;
      }
      if (find.byKey(const Key('product-auth-email')).evaluate().isNotEmpty) {
        return;
      }
      if (find.text('登录').evaluate().isNotEmpty) {
        return;
      }
      if (find.text('Sign In').evaluate().isNotEmpty) {
        return;
      }
    }
    if (!_isShellAuthenticated) {
      expect(find.byKey(const Key('product-auth-email')), findsWidgets);
    }
  }

  Future<void> login() async {
    _auditProgress('login_start');
    await _waitForLoginScreenOrShell(maxTicks: 120);
    if (_isShellAuthenticated) {
      _auditProgress('login_already_authed');
      return;
    }
    await tester.enterText(
      find.byKey(const Key('product-auth-email')),
      kDevAdminEmail,
    );
    await tester.enterText(
      find.byKey(const Key('product-auth-password')),
      kDevAdminPassword,
    );
    final submitFinder = find.byKey(const Key('product-auth-submit'));
    await tester.tap(submitFinder, warnIfMissed: false);
    await waitForShellReady(maxTicks: 120);
    _auditProgress('login_done');
  }

  Future<bool> tryTapTooltip(String tooltip) async {
    final finder = find.byTooltip(tooltip);
    if (finder.evaluate().isEmpty) {
      return false;
    }
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first, warnIfMissed: false);
    await pumpFrames(count: 16);
    return true;
  }

  Future<void> tapTooltip(String tooltip) async {
    final opened = await tryTapTooltip(tooltip);
    expect(opened, isTrue, reason: 'Tooltip not found: $tooltip');
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

  /// Loads task-center summary when the empty-state CTA is visible.
  Future<void> refreshTaskCenterIfPossible() async {
    final refreshZh = find.text('刷新任务摘要');
    final refreshEn = find.text('Refresh task summary');
    final refresh = refreshZh.evaluate().isNotEmpty ? refreshZh : refreshEn;
    if (refresh.evaluate().isEmpty) {
      return;
    }
    await tester.tap(refresh.first, warnIfMissed: false);
    await pumpFrames(count: 32);
  }

  Future<void> openMoreMenu() async {
    final moreZh = find.byTooltip('更多');
    final moreEn = find.byTooltip('More');
    if (moreZh.evaluate().isNotEmpty) {
      await tester.tap(moreZh.first, warnIfMissed: false);
    } else if (moreEn.evaluate().isNotEmpty) {
      await tester.tap(moreEn.first, warnIfMissed: false);
    } else {
      final apps = find.byIcon(Icons.apps_outlined);
      if (apps.evaluate().isNotEmpty) {
        await tester.tap(apps.last, warnIfMissed: false);
      } else {
        await tryTapTooltip('更多');
      }
    }
    await pumpFrames(count: 16);
    final sectionZh = find.text('制片与任务');
    final sectionEn = find.text('Production & tasks');
    final taskZh = find.text('任务中心');
    final taskEn = find.text('Task center');
    final ready = sectionZh.evaluate().isNotEmpty
        ? sectionZh
        : (sectionEn.evaluate().isNotEmpty
              ? sectionEn
              : (taskZh.evaluate().isNotEmpty ? taskZh : taskEn));
    try {
      await waitFor(ready, maxTicks: 48);
    } catch (_) {
      // Narrow macOS window: dialog may still be open without section headers in tree.
      await pumpFrames(count: 12);
    }
  }

  Future<bool> tryOpenMoreMenu() async {
    try {
      await openMoreMenu();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True when a dialog, bottom sheet, or modal barrier blocks the shell.
  bool get hasBlockingOverlay {
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      return true;
    }
    if (find.byType(BottomSheet).evaluate().isNotEmpty) {
      return true;
    }
    if (find.byType(ModalBarrier).evaluate().isNotEmpty) {
      return true;
    }
    return false;
  }

  /// Full-frame PNG when an overlay is open.
  Future<bool> captureOverlay(String overlayTag) async {
    return captureInteraction(overlayTag, requireOverlay: true);
  }

  Future<void> scrollProjectsActionsIntoView() async {
    await goProjectsHome();
    final labels = <String>[
      '打开画风工作台',
      'Open art styles workbench',
      '新建项目',
      'New project',
    ];
    for (final label in labels) {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        continue;
      }
      try {
        await tester.scrollUntilVisible(
          finder.first,
          160,
          scrollable: find.byType(Scrollable).first,
        );
      } catch (_) {}
      return;
    }
  }

  Future<bool> navigateToUtilityPane(ProductWorkspacePane pane) async {
    try {
      final shellRoot = find.byKey(const ValueKey<String>('studio-shell-root'));
      if (shellRoot.evaluate().isEmpty) {
        return false;
      }
      final element = tester.element(shellRoot.first);
      StudioShellNavigationScope.maybeOf(
        element,
      )?.selectProductWorkspacePane(pane);
      GoRouter.of(element).go(studioUriForUtilityPane(pane));
      await pumpFrames(count: 32);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// GoRouter-first route capture — avoids «更多» menu scroll on narrow viewports.
  Future<bool> tryNavigateAndCapture(
    String scenarioId,
    ProductWorkspacePane pane, {
    Future<void> Function()? afterNavigate,
  }) async {
    if (!await navigateToUtilityPane(pane)) {
      return false;
    }
    await pumpFrames(count: 24);
    if (afterNavigate != null) {
      await afterNavigate();
    }
    await capture(scenarioId);
    await goProjectsHome();
    return true;
  }

  Future<bool> tryOpenNotificationsPane() async {
    await pumpFrames(count: 16);
    if (await navigateToUtilityPane(ProductWorkspacePane.notifications)) {
      return true;
    }
    final strategies = <Finder>[
      find.byKey(const Key('studio-app-bar-notifications')),
      find.byTooltip('通知'),
      find.byTooltip('Notifications'),
      find.byIcon(Icons.notifications_rounded),
      find.byIcon(Icons.notifications_outlined),
    ];
    for (final finder in strategies) {
      if (finder.evaluate().isEmpty) {
        continue;
      }
      await tester.tap(finder.first, warnIfMissed: false);
      await pumpFrames(count: 24);
      return true;
    }
    await goProjectsHome();
    if (await trySelectMoreMenuItemI18n(<String>['通知中心', 'Notifications'])) {
      return true;
    }
    return false;
  }

  Future<void> openNotificationsPane() async {
    final opened = await tryOpenNotificationsPane();
    expect(opened, isTrue, reason: 'Could not open notifications pane');
  }

  Future<bool> tryOpenHelpHubPane() async {
    await pumpFrames(count: 12);
    if (await navigateToUtilityPane(ProductWorkspacePane.helpHub)) {
      return true;
    }
    final strategies = <Finder>[
      find.byTooltip('帮助'),
      find.byTooltip('Help'),
      find.byIcon(Icons.help_rounded),
      find.byIcon(Icons.help_outline),
    ];
    for (final finder in strategies) {
      if (finder.evaluate().isEmpty) {
        continue;
      }
      await tester.tap(finder.first, warnIfMissed: false);
      await pumpFrames(count: 24);
      return true;
    }
    await goProjectsHome();
    return trySelectMoreMenuItemI18n(<String>['帮助', 'Help']);
  }

  Future<void> openHelpHubPane() async {
    final opened = await tryOpenHelpHubPane();
    expect(opened, isTrue, reason: 'Could not open help hub');
  }

  bool get _settingsHubReady =>
      find.text('设置').evaluate().isNotEmpty &&
      find.byType(TabBar).evaluate().isNotEmpty;

  Future<bool> tryOpenSettingsHubCompactAware() async {
    await pumpFrames(count: 12);
    if (await navigateToUtilityPane(ProductWorkspacePane.account)) {
      await pumpFrames(count: 32);
      if (_settingsHubReady) {
        return true;
      }
    }
    final strategies = <Finder>[
      find.byTooltip('账户与设置'),
      find.byTooltip('Settings'),
      find.byIcon(Icons.settings_rounded),
      find.byIcon(Icons.settings_outlined),
    ];
    for (final finder in strategies) {
      if (finder.evaluate().isEmpty) {
        continue;
      }
      await tester.tap(finder.first, warnIfMissed: false);
      await pumpFrames(count: 32);
      if (_settingsHubReady) {
        return true;
      }
    }
    return false;
  }

  Future<void> openSettingsHubCompactAware() async {
    final opened = await tryOpenSettingsHubCompactAware();
    expect(opened, isTrue, reason: 'Could not open settings hub');
  }

  Future<bool> tryCaptureCollapsibleFilter(String tag) async {
    final panel = find.byKey(const Key('studio_collapsible_filter_panel'));
    if (panel.evaluate().isEmpty) {
      return false;
    }
    await captureInteraction('${tag}_filter_collapsed');
    await tester.tap(panel.first, warnIfMissed: false);
    await pumpFrames(count: 20);
    await captureInteraction('${tag}_filter_expanded');
    await tester.tap(panel.first, warnIfMissed: false);
    await pumpFrames(count: 12);
    return true;
  }

  /// Tap [label] (zh/en), capture overlay if shown, then dismiss.
  Future<bool> tryTapForOverlay(
    String label,
    String overlayTag, {
    bool dismissAfter = true,
  }) async {
    final finder = find.text(label);
    if (finder.evaluate().isEmpty) {
      return false;
    }
    try {
      await tester
          .tap(finder.first, warnIfMissed: false)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return false;
    }
    await pumpFrames(count: 12);
    final captured = await captureInteraction(overlayTag);
    if (dismissAfter) {
      await closeOverlay();
      await pumpFrames(count: 8);
    }
    return captured;
  }

  /// Try zh then en label variants.
  Future<bool> tryTapForOverlayI18n(
    List<String> labels,
    String overlayTag, {
    bool dismissAfter = true,
  }) async {
    for (final label in labels) {
      if (await tryTapForOverlay(
        label,
        overlayTag,
        dismissAfter: dismissAfter,
      )) {
        return true;
      }
    }
    return false;
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
    if (find.byType(ModalBarrier).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(12, 12));
      await pumpFrames();
    }
  }

  Future<bool> withAuditTimeout(
    Future<void> Function() action, {
    Duration timeout = const Duration(seconds: 75),
    String label = 'unknown',
  }) async {
    try {
      await action().timeout(timeout);
      return true;
    } catch (_) {
      await closeOverlay();
      await goProjectsHome();
      return false;
    }
  }

  Future<void> goProjectsHome() async {
    if (find.text('你的项目').evaluate().isNotEmpty ||
        find.text('新建项目').evaluate().isNotEmpty ||
        find.text('New project').evaluate().isNotEmpty) {
      return;
    }
    if (find.text('剧本').evaluate().isNotEmpty) {
      await exitProjectStudio();
      await pumpFrames(count: 16);
      if (find.text('新建项目').evaluate().isNotEmpty ||
          find.text('你的项目').evaluate().isNotEmpty) {
        return;
      }
    }
    final shellRoot = find.byKey(const ValueKey<String>('studio-shell-root'));
    if (shellRoot.evaluate().isNotEmpty) {
      GoRouter.of(tester.element(shellRoot.first)).go('/');
      await pumpFrames(count: 24);
      if (find.text('新建项目').evaluate().isNotEmpty ||
          find.text('你的项目').evaluate().isNotEmpty) {
        return;
      }
    }
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
    await openSettingsHubCompactAware();
  }

  Future<bool> trySelectMoreMenuItemI18n(List<String> labels) async {
    for (final label in labels) {
      if (await trySelectMoreMenuItem(label)) {
        return true;
      }
    }
    return false;
  }

  /// Opens settings hub tab by index (0 account · 1 plan · 2 API · 3 workspaces).
  ///
  /// Do **not** call [goProjectsHome] between tabs: that rebuilds the shell at `/`
  /// and drops [StudioSettingsHubNavigation] pending tab before [SettingsHubPage]
  /// mounts — every settings screenshot would look like the default tab.
  Future<void> openSettingsTabByIndex(int index) async {
    final tabIndex = index.clamp(0, 3);
    if (!_settingsHubReady) {
      StudioSettingsHubNavigation.requestTab(tabIndex);
      if (!await navigateToUtilityPane(ProductWorkspacePane.account)) {
        return;
      }
      await pumpFrames(count: 48);
      if (!_settingsHubReady) {
        return;
      }
    }
    final labels = switch (tabIndex) {
      0 => <String>['账户', 'Account'],
      1 => <String>['套餐与用量', 'Plan & usage'],
      2 => <String>['API 与模型', 'API & models'],
      _ => <String>['工作区', 'Workspaces'],
    };
    await openSettingsTabI18n(labels);
    await pumpFrames(count: 32);
  }

  Future<void> openSettingsTabI18n(List<String> labels) async {
    if (find.byType(TabBar).evaluate().isEmpty) {
      await navigateToUtilityPane(ProductWorkspacePane.account);
      await waitFor(find.byType(TabBar), maxTicks: 48);
    }
    final tabBar = find.byType(TabBar);
    for (final label in labels) {
      final tab = find.descendant(of: tabBar, matching: find.text(label));
      if (tab.evaluate().isNotEmpty) {
        try {
          await tester.ensureVisible(tab.first);
        } catch (_) {}
        await tester.tap(tab.first, warnIfMissed: false);
        await pumpFrames(count: 24);
        return;
      }
    }
  }

  /// Single-label alias used by gallery integration tests.
  Future<void> openSettingsTab(String label) async {
    await openSettingsTabI18n(<String>[label]);
  }

  Future<void> closeMoreMenuIfOpen() async {
    final close = find.byIcon(Icons.close_rounded);
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first, warnIfMissed: false);
      await pumpFrames();
      return;
    }
    if (find.byType(ModalBarrier).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(12, 12));
      await pumpFrames();
    }
  }

  Finder _moreMenuItem(String label) {
    return find.text(label);
  }

  Future<void> selectMoreMenuItem(
    String label, {
    bool menuAlreadyOpen = false,
  }) async {
    if (!menuAlreadyOpen) {
      await openMoreMenu();
    }
    final menuScroll = find.byType(Scrollable);
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
      await tester.drag(menuScroll.last, const Offset(0, -220));
      await pumpFrames(count: 6);
    }
    expect(
      _moreMenuItem(label),
      findsWidgets,
      reason: 'Missing «更多» item: $label',
    );
  }

  /// Returns false when the pane is absent from «更多» (e.g. platform toggles).
  Future<bool> trySelectMoreMenuItem(
    String label, {
    bool menuAlreadyOpen = false,
  }) async {
    try {
      await selectMoreMenuItem(label, menuAlreadyOpen: menuAlreadyOpen);
      return true;
    } catch (e) {
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

  Future<void> tapWizardAction(String label) async {
    final inSheet = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );
    final target = inSheet.evaluate().isNotEmpty
        ? inSheet.last
        : find.text(label).last;
    await tester.tap(target, warnIfMissed: false);
    await pumpFrames(count: 12);
  }

  Future<void> tapWizardActionI18n(List<String> labels) async {
    for (final label in labels) {
      final inSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(label),
      );
      if (inSheet.evaluate().isNotEmpty) {
        await tester.tap(inSheet.last, warnIfMissed: false);
        await pumpFrames(count: 12);
        return;
      }
    }
    throw TestFailure('Wizard action not found: ${labels.join(' / ')}');
  }

  Finder _wizardTitleFinder() {
    final zh = find.text('创建项目');
    if (zh.evaluate().isNotEmpty) {
      return zh;
    }
    return find.text('Create project');
  }

  Finder _wizardCreateButtonFinder() {
    for (final label in <String>['创建', 'Create']) {
      final inSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(StudioPrimaryButton, label),
      );
      if (inSheet.evaluate().isNotEmpty) {
        return inSheet;
      }
    }
    return find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(StudioPrimaryButton),
    );
  }

  Future<void> createProjectViaWizard(String projectName) async {
    final create = find.text('新建项目');
    final createEn = find.text('New project');
    final createTarget = create.evaluate().isNotEmpty ? create : createEn;
    expect(createTarget, findsWidgets);
    await tester.tap(createTarget.last, warnIfMissed: false);
    await waitFor(_wizardTitleFinder());
    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    await tester.enterText(fields.first, projectName);
    await pumpFrames();
    await tapWizardActionI18n(<String>['下一步', 'Next']);
    await tapWizardActionI18n(<String>['下一步', 'Next']);
    final createButton = _wizardCreateButtonFinder();
    await waitFor(createButton);
    await tester.tap(createButton, warnIfMissed: false);
    await pumpFrames(count: 16);
    for (var i = 0; i < 64; i++) {
      await pumpFrames(count: 1);
      if (find.byType(BottomSheet).evaluate().isEmpty) {
        break;
      }
    }
    final title = find.text(projectName);
    await _scrollIntoViewIfPossible(title);
    await waitFor(title, maxTicks: 80);
    await pumpFrames(count: 8);
  }

  Future<void> _scrollIntoViewIfPossible(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      return;
    }
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) {
      return;
    }
    try {
      await tester
          .scrollUntilVisible(finder, 200, scrollable: scrollables.first)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<bool> tryCreateSeedProjectViaApi(String projectName) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        return false;
      }
      final row = await createProject(
        session.accessToken,
        fields: <String, dynamic>{
          'name': projectName,
          'intro': 'E2E audit seed',
        },
      ).timeout(const Duration(seconds: 20));
      lastSeedProjectName = projectName;
      lastSeedProjectNumericId = row.numericId;
      await goProjectsHome();
      await pumpFrames(count: 16);
      _auditProgress('seed_project_api_${row.numericId}');
      return true;
    } catch (e) {
      print('E2E_AUDIT_SEED_API_FAIL=$e');
      return false;
    }
  }

  Future<bool> tryOpenSeedProjectStudioViaRoute() async {
    final numericId = lastSeedProjectNumericId;
    if (numericId != null && numericId > 0) {
      try {
        final shellRoot = find.byKey(const ValueKey<String>('studio-shell-root'));
        if (shellRoot.evaluate().isEmpty) {
          return false;
        }
        GoRouter.of(tester.element(shellRoot.first)).go(
          '/projects/$numericId/script',
        );
        await pumpFrames(count: 24);
        await assertProjectStudioEntered();
        return true;
      } catch (_) {
        await goProjectsHome();
      }
    }
    final name = lastSeedProjectName;
    if (name == null) {
      return false;
    }
    return tryOpenProjectByName(name);
  }

  Future<bool> tryCreateProjectViaWizard(String projectName) async {
    try {
      await createProjectViaWizard(
        projectName,
      ).timeout(const Duration(seconds: 90));
      lastSeedProjectName = projectName;
      return true;
    } catch (_) {
      await closeOverlay();
      await goProjectsHome();
      return false;
    }
  }

  Future<void> openProjectByName(String projectName) async {
    final title = find.text(projectName);
    await waitFor(title);
    await _scrollIntoViewIfPossible(title);

    final numericId = _numericIdForProjectTitle(projectName);
    final enterByKey = numericId > 0
        ? find.byKey(Key('project_enter_studio_$numericId'))
        : find.byKey(const Key('project_enter_studio_0'));
    if (numericId > 0 && enterByKey.evaluate().isNotEmpty) {
      await tester.tap(enterByKey.first, warnIfMissed: false);
    } else {
      final card = find.ancestor(
        of: title.first,
        matching: find.byType(Material),
      );
      final enterZh = find.descendant(
        of: card,
        matching: find.widgetWithText(StudioPrimaryButton, '进入工作室'),
      );
      final enterEn = find.descendant(
        of: card,
        matching: find.widgetWithText(StudioPrimaryButton, 'Open studio'),
      );
      final enterStudio = enterZh.evaluate().isNotEmpty ? enterZh : enterEn;
      await tester.tap(enterStudio, warnIfMissed: false);
    }

    await assertProjectStudioEntered();
  }

  int _numericIdForProjectTitle(String projectName) {
    final title = find.text(projectName);
    if (title.evaluate().isEmpty) {
      return 0;
    }
    final idChip = find.descendant(
      of: find.ancestor(of: title.first, matching: find.byType(Material)),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            RegExp(r'^#\d+$').hasMatch(widget.data!),
      ),
    );
    if (idChip.evaluate().isEmpty) {
      return 0;
    }
    final label = (idChip.evaluate().first.widget as Text).data!;
    return int.tryParse(label.replaceFirst('#', '')) ?? 0;
  }

  /// Confirms product-shell project studio route (not projects home grid).
  Future<void> assertProjectStudioEntered() async {
    await waitFor(find.text('剧本'), maxTicks: 80);
    expect(find.text('你的项目'), findsNothing);
    for (final step in <String>['美术', '资产', '分镜', '视频', '成片']) {
      expect(find.text(step), findsWidgets);
    }
    await pumpFrames(count: 24);
  }

  Future<bool> tryOpenProjectByName(String projectName) async {
    try {
      await openProjectByName(projectName);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> tryCaptureStudioStep(String stepLabel, String scenarioId) async {
    final step = find.text(stepLabel);
    if (step.evaluate().isEmpty) {
      return false;
    }
    await tester.tap(step.first);
    await pumpFrames(count: 20);
    await capture(scenarioId);
    return true;
  }

  /// Uses dev seed login ([kDevAdminEmail] / [kDevAdminPassword]) then real style-pack APIs.
  Future<bool> tryCaptureStudioArtStep() async {
    const chipLabels = <String>['2. 美术', '2. Art'];
    Finder? chip;
    for (final label in chipLabels) {
      final candidate = find.text(label);
      if (candidate.evaluate().isNotEmpty) {
        chip = candidate;
        break;
      }
    }
    if (chip == null) {
      return false;
    }
    await tester.tap(chip.first);
    await pumpFrames(count: 24);
    final loaded = find.byKey(const Key('studio_art_step_panel'));
    final saveZh = find.text('保存美术设定');
    final saveEn = find.text('Save art direction');
    await waitFor(
      loaded.evaluate().isNotEmpty
          ? loaded
          : (saveZh.evaluate().isNotEmpty ? saveZh : saveEn),
      maxTicks: 48,
    );
    await pumpFrames(count: 12);
    await capture('studio_step_art');
    return true;
  }

  Future<void> exitProjectStudio() async {
    final closeIcons = find.byIcon(Icons.close);
    if (closeIcons.evaluate().isNotEmpty) {
      await tester.tap(closeIcons.first, warnIfMissed: false);
      await pumpFrames(count: 20);
    }
    final back = find.byType(BackButton);
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first, warnIfMissed: false);
      await pumpFrames(count: 20);
    }
    final brand = find.byType(OpenFlowBrandMark);
    if (brand.evaluate().isNotEmpty && find.text('你的项目').evaluate().isEmpty) {
      await tester.tap(brand.first, warnIfMissed: false);
      await pumpFrames(count: 16);
    }
    final projectsTab = find.text('项目');
    if (projectsTab.evaluate().isNotEmpty &&
        find.text('你的项目').evaluate().isEmpty) {
      await tester.tap(projectsTab.first, warnIfMissed: false);
      await pumpFrames(count: 16);
    }
  }

  Future<bool> tryCaptureSeedProjectStudioInteractions() async {
    final name = lastSeedProjectName;
    if (name == null) {
      return false;
    }
    return withAuditTimeout(() async {
      if (!await tryOpenProjectByName(name)) {
        throw TestFailure('seed project not openable');
      }
      await captureInteraction('studio_script_entered');
      await tryTapForOverlayI18n(<String>[
        '导入小说',
        'Import novel',
        '剧本设置',
        'Script setup',
      ], 'studio_script_setup_sheet');
      await tryCaptureStudioStep('4. 分镜', 'storyboard_studio_step');
      await exitProjectStudio();
    }, label: 'seed_project_studio_interactions');
  }
}
