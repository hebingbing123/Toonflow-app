import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/global_search/global_search_bar.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/project_studio/studio_overlay_mode.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: StudioTheme.build(),
    home: child,
  );
}

void main() {
  testWidgets('compact product chrome keeps title and search visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        const HomePage(
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

    expect(find.text('OpenFlow'), findsOneWidget);
    expect(find.text('Storyboard studio'), findsOneWidget);
    expect(find.byType(GlobalSearchBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacked product chrome keeps title and search visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        const HomePage(
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

    expect(find.text('OpenFlow'), findsOneWidget);
    expect(find.text('Storyboard studio'), findsOneWidget);
    expect(find.byType(GlobalSearchBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
