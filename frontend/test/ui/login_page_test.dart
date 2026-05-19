import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/auth/controller.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/login_page.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';

/// Wave-1 scenario `login_error` — server/auth error surfaced on login card.
void main() {
  testWidgets('login_error shows auth error without raw exception text', (
    WidgetTester tester,
  ) async {
    final authController = AuthController(
      onErrorChanged: (_) {},
      onSignedOut: () async {},
      l10nProvider: () => null,
    );
    addTearDown(authController.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: StudioTheme.build(),
        builder: (context, child) => Theme(
          data: studioAdaptiveDesktopTheme(context),
          child: child ?? const SizedBox(),
        ),
        home: ProductLoginPage(
          authController: authController,
          errorMessage: '账号或密码错误',
          onSignIn: () {},
          onSignUp: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('账号或密码错误'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
