import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/episode_console/episode_console_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/storyboard_studio/storyboard_studio_page.dart';

import '../support/ui_gallery_capture.dart';

/// Wave-3 widget goldens (storyboard + episode console).
void main() {
  Widget wrap(Widget child, {Size? surfaceSize}) {
    Widget body = child;
    if (surfaceSize != null) {
      body = MediaQuery(
        data: MediaQueryData(size: surfaceSize),
        child: body,
      );
    }
    return MaterialApp(
      theme: buildStudioDarkTheme(useGoogleFonts: false),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: body),
    );
  }

  testWidgets('storyboard_studio golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        StoryboardStudioPage(
          projectNumericId: 7,
          projectUuid: '00000000-0000-0000-0000-000000000099',
          accessToken: 'golden-token',
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
              prompt: 'Hero enters the room',
              state: '草稿',
              sbIndex: 1,
            ),
            ProductionStoryboardItemV1(
              id: 2,
              scriptId: 1,
              prompt: 'Close-up reaction',
              state: '草稿',
              sbIndex: 2,
            ),
          ],
        ),
        surfaceSize: const Size(1280, 720),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.text('Storyboard studio'),
      matchesGoldenFile(goldenPathForScenario('storyboard_studio')),
    );
  });

  testWidgets('episode_console golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        EpisodeConsolePage(
          projectNumericId: 7,
          scriptNumericId: 1,
          deliverChild: const Center(child: Text('deliver-body')),
          onOpenFullStudio: () {},
        ),
        surfaceSize: const Size(1280, 720),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.text('Episode 1'),
      matchesGoldenFile(goldenPathForScenario('episode_console')),
    );
  });
}
