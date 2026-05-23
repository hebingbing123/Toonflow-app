import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_job_tray.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/benchmark/section.dart';
import 'package:openflow_app/content_compliance/section.dart';
import 'package:openflow_app/jobs/section.dart';
import 'package:openflow_app/product_shell/login_page.dart';
import 'package:openflow_app/product_shell/settings_hub_page.dart';
import 'package:openflow_app/projects/section.dart';
import 'package:openflow_app/quality_reviews/section.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/task_center/section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/desktop_layout_fixtures.dart';
import '../support/ignore_layout_overflow.dart';
import '../support/product_shell_chrome_fixture.dart';
import '../support/tolerant_golden_comparator.dart';
import '../support/ui_gallery_capture.dart';

/// Widget goldens for key desktop layouts (CI-friendly; no integration device).
void main() {
  goldenFileComparator = TolerantLocalFileComparator(
    Uri.parse('test/ui/desktop_layout_widget_gallery_test.dart'),
    // Login ambient gradient can drift ~0.02% across full-suite font state.
    precisionTolerance: 0.001,
  );

  const desktopSize = Size(1440, 960);

  Widget wrapDesktop(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildStudioDarkTheme(useBundledFonts: true),
      home: Scaffold(body: child),
    );
  }

  testWidgets('product_shell_chrome desktop layout golden', (tester) async {
    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(buildProductShellChromePreview()),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(StudioJobTray),
      matchesGoldenFile(goldenPathForDesktopLayout('02_product_shell_chrome')),
    );
  });

  testWidgets('login_default desktop layout golden', (tester) async {
    final authController = buildDesktopGalleryAuthController();
    addTearDown(authController.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ProductLoginPage(
            authController: authController,
            errorMessage: null,
            onSignIn: () {},
            onSignUp: () {},
          ),
        ),
      ),
    );
    await pumpIgnoringBenignLayoutOverflow(tester);
    await pumpIgnoringBenignLayoutOverflow(
      tester,
      const Duration(milliseconds: 200),
    );

    await expectLater(
      find.byType(ProductLoginPage),
      matchesGoldenFile(goldenPathForDesktopLayout('01_login')),
    );
  });

  testWidgets('projects_default desktop layout golden', (tester) async {
    final projectsController = buildDesktopGalleryProjectsController();
    addTearDown(projectsController.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        ProjectsSection(
          accessToken: 'token',
          controller: projectsController,
          onOpenProjectDetail: (_) {},
          onOpenTeamWorkspaces: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ProjectsSection),
      matchesGoldenFile(goldenPathForDesktopLayout('03_projects')),
    );
  });

  testWidgets('tasks_default desktop layout golden', (tester) async {
    final taskDetailController = TextEditingController();
    addTearDown(taskDetailController.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        buildDesktopGalleryTaskCenter(
          taskDetailController: taskDetailController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TaskCenterSection),
      matchesGoldenFile(goldenPathForDesktopLayout('04_task_center')),
    );
  });

  testWidgets('quality_default desktop layout golden', (tester) async {
    final qualityController = buildDesktopGalleryQualityController();
    addTearDown(qualityController.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        SingleChildScrollView(
          child: QualityReviewsSection(
            accessToken: 'token',
            controller: qualityController,
            initialProjectNumericId: 9,
            platformConfig: PlatformConfigToggleSetV1.defaults,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(QualityReviewsSection),
      matchesGoldenFile(goldenPathForDesktopLayout('05_quality')),
    );
  });

  testWidgets('settings_account desktop layout golden', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = buildDesktopGallerySettingsControllers();
    addTearDown(settings.account.dispose);
    addTearDown(settings.apiKeys.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        SettingsHubPage(
          accountController: settings.account,
          apiKeysController: settings.apiKeys,
          accessToken: null,
          onAccountDeleted: (_) async {},
          onWorkspaceContextChanged: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsHubPage),
      matchesGoldenFile(goldenPathForDesktopLayout('06_settings_account')),
    );
  });

  testWidgets('settings_api desktop layout golden', (tester) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = buildDesktopGallerySettingsControllers();
    addTearDown(settings.account.dispose);
    addTearDown(settings.apiKeys.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        SettingsHubPage(
          accountController: settings.account,
          apiKeysController: settings.apiKeys,
          accessToken: null,
          onAccountDeleted: (_) async {},
          onWorkspaceContextChanged: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.studioSettingsTabApiKeys));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsHubPage),
      matchesGoldenFile(goldenPathForDesktopLayout('07_settings_api')),
    );
  });

  testWidgets('settings_plan_usage desktop layout golden', (tester) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = buildDesktopGallerySettingsControllers();
    addTearDown(settings.account.dispose);
    addTearDown(settings.apiKeys.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        SettingsHubPage(
          accountController: settings.account,
          apiKeysController: settings.apiKeys,
          accessToken: null,
          onAccountDeleted: (_) async {},
          onWorkspaceContextChanged: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.studioSettingsTabPlanUsage));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsHubPage),
      matchesGoldenFile(goldenPathForDesktopLayout('06a_settings_plan_usage')),
    );
  });

  testWidgets('settings_workspaces desktop layout golden', (tester) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = buildDesktopGallerySettingsControllers();
    addTearDown(settings.account.dispose);
    addTearDown(settings.apiKeys.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        SettingsHubPage(
          accountController: settings.account,
          apiKeysController: settings.apiKeys,
          accessToken: null,
          onAccountDeleted: (_) async {},
          onWorkspaceContextChanged: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.studioSettingsTabWorkspaces));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsHubPage),
      matchesGoldenFile(goldenPathForDesktopLayout('08_settings_workspaces')),
    );
  });

  testWidgets('benchmark_default desktop layout golden', (tester) async {
    final zh = AppLocalizationsZh();

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        const SingleChildScrollView(
          child: BenchmarkSection(accessToken: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.text(zh.benchmarkSectionTitle),
      matchesGoldenFile(goldenPathForDesktopLayout('12_benchmark')),
    );
  });

  testWidgets('jobs_default desktop layout golden', (tester) async {
    final jobsController = buildDesktopGalleryJobsController();
    addTearDown(jobsController.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        JobsSection(controller: jobsController, studioPresentation: true),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(JobsSection),
      matchesGoldenFile(goldenPathForDesktopLayout('11_jobs')),
    );
  });

  testWidgets('content_compliance desktop layout golden', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = buildDesktopGalleryContentComplianceController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(desktopSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapDesktop(
        SingleChildScrollView(
          child: ContentComplianceSection(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ContentComplianceSection),
      matchesGoldenFile(goldenPathForDesktopLayout('09_content_compliance')),
    );
  });
}
