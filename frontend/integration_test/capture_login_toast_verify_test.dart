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
import 'package:supabase_flutter/supabase_flutter.dart';

/// Captures login page clean + after sign-out with toast cleared.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  final outputDir =
      '${Directory.systemTemp.path}/openflow_login_toast_verify';

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

  testWidgets('login page has no overlay toast after sign-out', (
    WidgetTester tester,
  ) async {
    await ensureSupabaseReady();
    await AppLocaleNotifier.instance.load();
    await AppLocaleNotifier.instance.setLocaleCode('zh');
    await StudioOnboardingCoach.markSeen();
    await Supabase.instance.client.auth.signOut();

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repaintKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: repaintKey, child: const StudioProductApp()),
    );

    final loginEmail = find.byKey(const Key('product-auth-email'));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (loginEmail.evaluate().isNotEmpty) {
        break;
      }
    }
    expect(loginEmail, findsOneWidget);

    Future<void> writePng(String name) async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(outputDir).create(recursive: true);
      final file = File('$outputDir/$name');
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    }

    await writePng('01_login_clean.png');

    await tester.enterText(loginEmail, kDevAdminEmail);
    await tester.enterText(
      find.byKey(const Key('product-auth-password')),
      kDevAdminPassword,
    );
    await tester.tap(find.byKey(const Key('product-auth-submit')));
    await tester.pump();

    final shellReady = find.byKey(const Key('studio-app-bar-notifications'));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (shellReady.evaluate().isNotEmpty) {
        break;
      }
    }
    expect(shellReady, findsOneWidget);

    final l10n = lookupAppLocalizations(const Locale('zh'));
    showStudioSnackBar(
      tester.element(shellReady),
      message: l10n.studioVendorSetupSnackMessage,
      icon: Icons.vpn_key_outlined,
      actionLabel: l10n.studioVendorSetupSnackAction,
      onAction: () {},
    );
    await tester.pump(const Duration(milliseconds: 400));
    await writePng('02_shell_with_toast.png');
    expect(find.textContaining('API Key'), findsOneWidget);

    await tester.tap(find.byTooltip('退出'));
    await tester.pump();
    await Supabase.instance.client.auth.signOut();
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (loginEmail.evaluate().isNotEmpty &&
          shellReady.evaluate().isEmpty) {
        break;
      }
    }
    expect(loginEmail, findsOneWidget);
    expect(shellReady, findsNothing);
    expect(find.textContaining('API Key'), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await writePng('03_login_after_sign_out_no_toast.png');

    print('LOGIN_VERIFY_DIR=$outputDir');
    expect(
      File('$outputDir/03_login_after_sign_out_no_toast.png').existsSync(),
      isTrue,
    );
  });
}
