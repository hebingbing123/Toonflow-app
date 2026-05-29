import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/ignore_layout_overflow.dart';
import 'package:openflow_app/auth/controller.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/login_page.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';

void main() {
  AuthController buildAuthController() {
    return AuthController(
      onErrorChanged: (_) {},
      onSignedOut: () async {},
      l10nProvider: () => null,
    );
  }

  Widget buildTestApp({
    required AuthController authController,
    required VoidCallback onSignIn,
    required VoidCallback onSignUp,
    String? errorMessage,
    Size size = const Size(1440, 1024),
  }) {
    return MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: true),
      child: MaterialApp(
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
          errorMessage: errorMessage,
          onSignIn: onSignIn,
          onSignUp: onSignUp,
        ),
      ),
    );
  }

  testWidgets('product login submit shows loading while auth is in flight', (
    WidgetTester tester,
  ) async {
    final authController = buildAuthController();
    addTearDown(authController.dispose);

    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildTestApp(
        authController: authController,
        onSignIn: () {},
        onSignUp: () {},
      ),
    );
    await tester.pump();

    authController.debugSetAuthInFlight(true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    authController.debugSetAuthInFlight(false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('product login page keeps wide layout and forwards actions', (
    WidgetTester tester,
  ) async {
    final authController = buildAuthController();
    addTearDown(authController.dispose);
    var signInTapped = 0;
    var signUpTapped = 0;

    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildTestApp(
        authController: authController,
        onSignIn: () => signInTapped++,
        onSignUp: () => signUpTapped++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('OpenFlow'), findsOneWidget);
    expect(find.byKey(const Key('product-auth-submit')), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
    expect(find.byKey(const Key('auth-mode-sign-up')), findsOneWidget);

    await tester.tap(find.byKey(const Key('product-auth-submit')));
    await tester.pumpAndSettle();
    expect(signInTapped, 1);
    await tester.tap(find.byKey(const Key('auth-mode-sign-up')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-auth-password-confirm')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('product-auth-password-confirm')),
      'mismatch',
    );
    await tester.tap(find.byKey(const Key('product-auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('两次输入的密码不一致。'), findsOneWidget);
    expect(signUpTapped, 0);

    await tester.enterText(
      find.byKey(const Key('product-auth-password-confirm')),
      authController.passwordController.text,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-auth-submit')));
    await tester.pumpAndSettle();

    expect(signInTapped, 1);
    expect(signUpTapped, 1);
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('product login page stays usable on narrow viewports', (
    WidgetTester tester,
  ) async {
    final authController = buildAuthController();
    addTearDown(authController.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildTestApp(
        authController: authController,
        onSignIn: () {},
        onSignUp: () {},
        errorMessage: '账号或密码错误',
        size: const Size(390, 844),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('账号或密码错误'), findsOneWidget);
    expect(find.byKey(const Key('auth-mode-sign-up')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('auth-mode-sign-up')));
    await tester.tap(find.byKey(const Key('auth-mode-sign-up')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('确认密码'), findsOneWidget);

    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('product login page simplifies hero on short viewports', (
    WidgetTester tester,
  ) async {
    final authController = buildAuthController();
    addTearDown(authController.dispose);

    await tester.binding.setSurfaceSize(const Size(799, 452));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildTestApp(
        authController: authController,
        onSignIn: () {},
        onSignUp: () {},
        size: const Size(799, 452),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.byKey(const Key('product-auth-submit')), findsOneWidget);
    // Tall marketing stage is omitted when height < 560px.
    expect(find.text('OpenFlow'), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
