import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/storyboard_studio/storyboard_studio_page.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets('storyboard studio renders chrome and grid action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapApp(
        child: StoryboardStudioPage(
          projectNumericId: 7,
          projectUuid: '00000000-0000-0000-0000-000000000099',
          accessToken: 'test-token',
          onOpenProductionWorkspace: () {},
          debugScripts: const [
            ScriptWorkbenchDetailRow(
              numericId: 1,
              name: 'Episode 1',
              relatedAssets: [],
            ),
          ],
          debugShots: const [
            ProductionStoryboardItemV1(
              id: 1,
              scriptId: 1,
              prompt: 'Shot prompt',
              state: 'draft',
              sbIndex: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Storyboard studio'), findsOneWidget);
    expect(find.text('Shots'), findsOneWidget);
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Grid mode'), findsOneWidget);
    expect(find.text('Open production'), findsWidgets);
    expect(
      find.textContaining('split into cells'),
      findsOneWidget,
    );
  });
}
