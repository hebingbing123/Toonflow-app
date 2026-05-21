import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/config.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';
import 'package:openflow_app/design_system/components/studio_onboarding_coach.dart';
import 'package:openflow_app/locale/app_locale_notifier.dart';
import 'package:openflow_app/product_shell/studio_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Slimmer E2E than [real_product_shell_auth_gallery_test]: Supabase login + shell chrome only.
///
/// Run with local stack defines (same as [scripts/run-ui-e2e.sh] smoke):
/// `flutter test integration_test/real_product_shell_auth_smoke_test.dart -d macos \
///   --dart-define-from-file=dart_defines.dev.json`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

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

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int maxTicks = 80,
  }) async {
    for (var i = 0; i < maxTicks; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    expect(finder, findsWidgets);
  }

  testWidgets('login and reach projects shell', (WidgetTester tester) async {
    await ensureSupabaseReady();
    await AppLocaleNotifier.instance.load();
    await AppLocaleNotifier.instance.setLocaleCode('zh');
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await StudioOnboardingCoach.markSeen();
    await Supabase.instance.client.auth.signOut();

    await tester.pumpWidget(const StudioProductApp());
    await waitFor(tester, find.text('登录'));

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
    await waitFor(
      tester,
      find.byKey(const Key('studio-app-bar-notifications')),
    );

    expect(find.byKey(const Key('studio-app-bar-notifications')), findsOneWidget);
    expect(find.byTooltip('账户与设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
