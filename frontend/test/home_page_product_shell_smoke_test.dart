import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';

Widget _buildTestApp({
  required Widget child,
  Size size = const Size(1440, 900),
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, widget) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: widget ?? const SizedBox(),
      ),
      home: child,
    ),
  );
}

void main() {
  testWidgets(
    'home page can render storyboard overlay with injected auth seam',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestApp(
          child: const HomePage(
            shellMode: HomeShellMode.product,
            studioOverlay: StudioOverlayMode.storyboardStudio,
            studioProjectNumericId: 7,
            debugAuthenticatedAccessToken: 'test-token',
            debugSkipSessionContextSync: true,
            debugSkipAuthListenerAttach: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Storyboard studio'), findsOneWidget);
      expect(find.text('OpenFlow'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('product-auth-submit')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home page can render episode console overlay with injected auth seam',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestApp(
          child: const HomePage(
            shellMode: HomeShellMode.product,
            studioOverlay: StudioOverlayMode.episodeConsole,
            studioProjectNumericId: 7,
            studioScriptNumericId: 3,
            debugAuthenticatedAccessToken: 'test-token',
            debugSkipSessionContextSync: true,
            debugSkipAuthListenerAttach: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Episode 3'), findsOneWidget);
      expect(find.text('Full studio'), findsOneWidget);
      expect(find.byKey(const Key('product-auth-submit')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home page can render project studio overlay with injected auth seam',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestApp(
          child: HomePage(
            shellMode: HomeShellMode.product,
            studioOverlay: StudioOverlayMode.projectStudio,
            studioProjectNumericId: 7,
            studioStepSlug: 'script',
            debugAuthenticatedAccessToken: 'test-token',
            debugSkipSessionContextSync: true,
            debugSkipAuthListenerAttach: true,
            debugStudioProjectUuid: 'project-7',
            debugStudioProjectName: 'Project Delta',
            debugProjectStudioSnapshotLoader:
                (accessToken, projectUuid) async =>
                    const StudioReadinessSnapshot(completedSteps: 4),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Project Delta'), findsOneWidget);
      expect(find.text('4/6'), findsOneWidget);
      expect(find.text('Episode console'), findsOneWidget);
      expect(find.byKey(const Key('product-auth-submit')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
