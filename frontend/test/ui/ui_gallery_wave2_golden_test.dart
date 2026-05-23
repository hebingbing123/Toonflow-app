import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_pane_header.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/notifications/controller.dart';
import 'package:openflow_app/notifications/section.dart';
import 'package:openflow_app/project_studio/project_studio_page.dart';
import 'package:openflow_app/project_studio/studio_agent_quick_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/project_studio_fixture.dart';
import '../support/studio_workbench_section_test_support.dart';
import '../support/studio_golden_app.dart';
import '../support/ui_gallery_capture.dart';
import 'search_no_results_test.dart';

/// Wave-2 widget goldens under [test/goldens/ui_gallery/].
void main() {
  const gallerySize = Size(720, 520);

  testWidgets('notifications_studio golden', (tester) async {
    final zh = AppLocalizationsZh();
    final controller = NotificationsController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => zh,
    );
    controller.items = const [];
    controller.loading = false;

    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: gallerySize,
        child: NotificationsSection(
          studioPresentation: true,
          controller: controller,
          onOpenNotification: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.text(zh.notificationsCenterTitle),
      matchesGoldenFile(goldenPathForScenario('notifications_studio')),
    );
  });

  testWidgets('short_video_overview golden', (tester) async {
    final zh = AppLocalizationsZh();
    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: const Size(720, 160),
        child: StudioPaneHeader(
          title: zh.shortVideoSpacePageTitle,
          subtitle: zh.shortVideoSpacePageSubtitle,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StudioPaneHeader),
      matchesGoldenFile(goldenPathForScenario('short_video_overview')),
    );
  });

  testWidgets('studio_step_art golden', (tester) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_7': 'art',
    });

    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectStudioPage(host: buildArtStepStudioHost(l10n: zh)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('studio_art_step_panel')),
      matchesGoldenFile(goldenPathForScenario('studio_step_art')),
    );
  });

  testWidgets('studio_step_script golden', (tester) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_7': 'script',
    });

    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectStudioPage(host: buildScriptStepStudioHost(l10n: zh)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(zh.studioScriptStepSetupOpen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expandAllStudioWorkbenchSections(tester);

    await expectLater(
      find.byType(StudioAgentQuickBar),
      matchesGoldenFile(goldenPathForScenario('studio_step_script')),
    );
  });

  testWidgets('search_empty golden', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: gallerySize,
        child: Builder(builder: buildSearchNoResultsIllustration),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byIcon(Icons.search_off),
      matchesGoldenFile(goldenPathForScenario('search_empty')),
    );
  });
}
