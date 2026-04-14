import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/config.dart';
import 'package:openflow_app/home_page/auth/section_view.dart';

void noop() {}

AuthSectionViewModel buildModel({
  required TextEditingController emailController,
  required TextEditingController passwordController,
  bool signedIn = false,
  bool loadingMe = false,
  bool loadingDevSwitchProbe = false,
  bool loadingMemoryConfigProbe = false,
  bool loadingAboutProbe = false,
  bool loadingUsageSummary = false,
  bool loadingPromptsProbe = false,
  bool loadingVisualManualProbe = false,
  bool loadingDirectorManualProbe = false,
  bool loadingSkillsBinaryProbe = false,
  bool loadingModelsCatalog = false,
  bool loadingTextModelDefault = false,
  bool loadingModelDetail = false,
  String? meBody = '{"id":"user-1"}',
  String? devSwitchProbeBody = '{"enabled":true}',
  String? memoryConfigProbeBody = '{"memory":true}',
  String? aboutProbeBody = '{"version":"1.0.0"}',
  String? usageSummaryBody = '{"events":3}',
  String? promptsProbeBody = '{"prompt":"ok"}',
  String? visualManualProbeBody = '{"visual_manual_id":1}',
  String? directorManualProbeBody = '{"director_manual_id":2}',
  String? skillsBinaryProbeBody = 'png-bytes=12',
  String? modelsCatalogBody = '{"models":["gpt-4o-mini"]}',
  String? textModelDefaultBody = '{"default":"gpt-4o-mini"}',
  String? modelDetailBody = '{"id":"gpt-4o-mini"}',
}) {
  return AuthSectionViewModel(
    signedIn: signedIn,
    session: null,
    emailController: emailController,
    passwordController: passwordController,
    loadingMe: loadingMe,
    loadingDevSwitchProbe: loadingDevSwitchProbe,
    loadingMemoryConfigProbe: loadingMemoryConfigProbe,
    loadingAboutProbe: loadingAboutProbe,
    loadingUsageSummary: loadingUsageSummary,
    loadingPromptsProbe: loadingPromptsProbe,
    loadingVisualManualProbe: loadingVisualManualProbe,
    loadingDirectorManualProbe: loadingDirectorManualProbe,
    loadingSkillsBinaryProbe: loadingSkillsBinaryProbe,
    loadingModelsCatalog: loadingModelsCatalog,
    loadingTextModelDefault: loadingTextModelDefault,
    loadingModelDetail: loadingModelDetail,
    meBody: meBody,
    devSwitchProbeBody: devSwitchProbeBody,
    memoryConfigProbeBody: memoryConfigProbeBody,
    aboutProbeBody: aboutProbeBody,
    usageSummaryBody: usageSummaryBody,
    promptsProbeBody: promptsProbeBody,
    visualManualProbeBody: visualManualProbeBody,
    directorManualProbeBody: directorManualProbeBody,
    skillsBinaryProbeBody: skillsBinaryProbeBody,
    modelsCatalogBody: modelsCatalogBody,
    textModelDefaultBody: textModelDefaultBody,
    modelDetailBody: modelDetailBody,
  );
}

AuthSectionViewCallbacks buildCallbacks({
  VoidCallback? onSignIn = noop,
  VoidCallback? onSignUp = noop,
  VoidCallback? onSignOut = noop,
  VoidCallback? onCallMe = noop,
  VoidCallback? onCallDevSwitchProbe = noop,
  VoidCallback? onCallMemoryConfigProbe = noop,
  VoidCallback? onCallAboutProbe = noop,
  VoidCallback? onCallUsageSummary = noop,
  VoidCallback? onCallPromptsProbe = noop,
  VoidCallback? onCallVisualManualProbe = noop,
  VoidCallback? onCallDirectorManualProbe = noop,
  VoidCallback? onCallSkillsBinaryProbe = noop,
  VoidCallback? onCallModelsCatalog = noop,
  VoidCallback? onCallTextModelDefault = noop,
  VoidCallback? onCallModelDetail = noop,
}) {
  return AuthSectionViewCallbacks(
    onSignIn: onSignIn,
    onSignUp: onSignUp,
    onSignOut: onSignOut,
    onCallMe: onCallMe,
    onCallDevSwitchProbe: onCallDevSwitchProbe,
    onCallMemoryConfigProbe: onCallMemoryConfigProbe,
    onCallAboutProbe: onCallAboutProbe,
    onCallUsageSummary: onCallUsageSummary,
    onCallPromptsProbe: onCallPromptsProbe,
    onCallVisualManualProbe: onCallVisualManualProbe,
    onCallDirectorManualProbe: onCallDirectorManualProbe,
    onCallSkillsBinaryProbe: onCallSkillsBinaryProbe,
    onCallModelsCatalog: onCallModelsCatalog,
    onCallTextModelDefault: onCallTextModelDefault,
    onCallModelDetail: onCallModelDetail,
  );
}

void main() {
  late TextEditingController emailController;
  late TextEditingController passwordController;

  setUp(() {
    emailController = TextEditingController(text: 'demo@example.com');
    passwordController = TextEditingController(text: 'secret');
  });

  tearDown(() {
    emailController.dispose();
    passwordController.dispose();
  });

  testWidgets('auth section view renders auth shell for current config state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthSectionView(
            model: buildModel(
              emailController: emailController,
              passwordController: passwordController,
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('Supabase Auth'), findsOneWidget);
    if (kSupabaseConfigured) {
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '注册'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '退出'), findsNothing);
      expect(find.textContaining('GET /api/v1/me'), findsNothing);
    } else {
      expect(find.textContaining('未配置：运行示例'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Password'), findsNothing);
      expect(find.text('登录'), findsNothing);
      expect(find.text('注册'), findsNothing);
    }
  });

  testWidgets(
    'auth section view renders signed-in probes and disables busy actions',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthSectionView(
              model: buildModel(
                emailController: emailController,
                passwordController: passwordController,
                signedIn: true,
                loadingMe: true,
                loadingModelsCatalog: true,
              ),
              callbacks: buildCallbacks(
                onCallMe: null,
                onCallModelsCatalog: null,
              ),
            ),
          ),
        ),
      );

      if (kSupabaseConfigured) {
        expect(find.text('退出'), findsOneWidget);
        expect(find.text('/me: {"id":"user-1"}'), findsOneWidget);
        expect(find.text('models: {"models":["gpt-4o-mini"]}'), findsOneWidget);
        expect(find.text('请求中…'), findsNWidgets(2));

        final busyButtons = tester.widgetList<ButtonStyleButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is ButtonStyleButton &&
                widget.onPressed == null &&
                widget.child is Text &&
                (((widget.child as Text).data ?? '').contains('请求中…')),
          ),
        );
        expect(busyButtons.length, 2);
      } else {
        expect(find.text('退出'), findsNothing);
        expect(find.text('请求中…'), findsNothing);
        expect(find.textContaining('未配置：运行示例'), findsOneWidget);
      }
    },
  );

  testWidgets('auth section view forwards auth actions when auth is enabled', (
    WidgetTester tester,
  ) async {
    var signInTapped = 0;
    var signUpTapped = 0;
    var signOutTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthSectionView(
            model: buildModel(
              emailController: emailController,
              passwordController: passwordController,
              signedIn: true,
            ),
            callbacks: buildCallbacks(
              onSignIn: () => signInTapped++,
              onSignUp: () => signUpTapped++,
              onSignOut: () => signOutTapped++,
            ),
          ),
        ),
      ),
    );

    if (kSupabaseConfigured) {
      await tester.tap(find.text('登录'));
      await tester.pump();
      await tester.tap(find.text('注册'));
      await tester.pump();
      await tester.tap(find.text('退出'));
      await tester.pump();

      expect(signInTapped, 1);
      expect(signUpTapped, 1);
      expect(signOutTapped, 1);
    } else {
      expect(find.text('登录'), findsNothing);
      expect(find.text('注册'), findsNothing);
      expect(find.text('退出'), findsNothing);
      expect(signInTapped, 0);
      expect(signUpTapped, 0);
      expect(signOutTapped, 0);
    }
  });
}
