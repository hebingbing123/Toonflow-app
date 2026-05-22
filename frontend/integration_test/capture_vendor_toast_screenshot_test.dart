// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/config.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';
import 'package:openflow_app/design_system/components/studio_onboarding_coach.dart';
import 'package:openflow_app/design_system/ix/studio_snackbar.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/locale/app_locale_notifier.dart';
import 'package:openflow_app/product_shell/studio_app.dart';
import 'package:openflow_app/settings/model_vendors/domestic_vendor_setup_prefs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One-off capture: projects home with top-right vendor nudge toast visible.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  final outputDir =
      '${Directory.systemTemp.path}/openflow_toast_capture_verify';

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

  testWidgets('capture vendor toast on projects home', (tester) async {
    await ensureSupabaseReady();
    await AppLocaleNotifier.instance.load();
    await AppLocaleNotifier.instance.setLocaleCode('zh');
    await StudioOnboardingCoach.markSeen();
    await DomesticVendorSetupPrefs.clearDismissedForTests();
    await Supabase.instance.client.auth.signOut();

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repaintKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: repaintKey, child: const StudioProductApp()),
    );

    await tester.pump(const Duration(milliseconds: 500));
    final loginEmail = find.byKey(const Key('product-auth-email'));
    final loginTab = find.text('登录');
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (loginEmail.evaluate().isNotEmpty ||
          loginTab.evaluate().isNotEmpty) {
        break;
      }
    }
    expect(loginEmail, findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('product-auth-email')),
      kDevAdminEmail,
    );
    await tester.enterText(
      find.byKey(const Key('product-auth-password')),
      kDevAdminPassword,
    );
    await tester.tap(find.byKey(const Key('product-auth-submit')));
    await tester.pump();

    Finder shellReady = find.byKey(const Key('studio-app-bar-notifications'));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (shellReady.evaluate().isNotEmpty &&
          repaintKey.currentContext != null) {
        break;
      }
    }
    expect(shellReady, findsOneWidget);
    expect(repaintKey.currentContext, isNotNull);

    await tester.pump(const Duration(milliseconds: 1200));

    Future<void> writePng(String name) async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(outputDir).create(recursive: true);
      final file = File('$outputDir/$name');
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    }

    await writePng('projects_home_after_login.png');

    // Force vendor-style toast so capture proves top-right glass chrome.
    final chrome = find.byKey(const Key('studio-app-bar-notifications'));
    final l10n = lookupAppLocalizations(const Locale('zh'));
    showStudioSnackBar(
      tester.element(chrome),
      message: l10n.studioVendorSetupSnackMessage,
      icon: Icons.vpn_key_outlined,
      actionLabel: l10n.studioVendorSetupSnackAction,
      onAction: () {},
    );
    await tester.pump(const Duration(milliseconds: 400));
    await writePng('projects_home_top_right_toast.png');
    print('TOAST_CAPTURE_DIR=$outputDir');
    expect(
      File('$outputDir/projects_home_top_right_toast.png').existsSync(),
      isTrue,
    );
  });
}
