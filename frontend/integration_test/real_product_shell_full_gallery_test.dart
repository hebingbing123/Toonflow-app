import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';

import 'support/real_product_shell_gallery_support.dart';

/// Full-stack PNG gallery: Supabase login + Rust API + real [StudioProductApp] navigation.
///
/// Dev login: `admin@openflow.local` / `admin123` ([kDevAdminEmail] in config.dart).
///
/// Run: `OPENFLOW_UI_E2E_SKIP_RESET=1 bash scripts/run-ui-e2e.sh --full-gallery`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  testWidgets('capture full real product shell gallery', (WidgetTester tester) async {
    final harness = RealProductShellGalleryHarness(tester);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await harness.bootstrap();
    await harness.capture('login_default');
    await harness.login();
    await harness.capture('projects_default');

    await harness.tapTooltip('通知');
    await harness.refreshNotificationsIfPossible();
    await harness.capture('notifications_studio');

    await harness.openSettingsHub();
    await harness.capture('settings_account');
    await harness.openSettingsTab('套餐与用量');
    await harness.capture('settings_plan_usage');
    await harness.openSettingsTab('API 与模型');
    await harness.capture('settings_api');
    await harness.openSettingsTab('工作区');
    await harness.capture('settings_workspaces');

    await harness.goProjectsHome();
    await harness.openMoreMenu();
    await harness.capture('more_menu');

    await harness.selectMoreMenuItem('任务中心', menuAlreadyOpen: true);
    await harness.pumpFrames(count: 24);
    await harness.capture('tasks_default');

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('质量评审');
    await harness.capture('quality_default');

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('任务作业');
    await harness.capture('jobs_default');

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('多平台分发');
    await harness.capture('short_video_overview');

    if (await harness.trySelectMoreMenuItem('团队工作区')) {
      await harness.capture('team_workspaces');
    }

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('API 密钥');
    await harness.capture('settings_api_keys_pane');

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('内容合规');
    await harness.capture('content_compliance_queue');

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('平台状态');
    await harness.capture('platform_status');

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('平台配置');
    await harness.capture('platform_config');

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('剧本工作区');
    await harness.capture('script_workspace');

    await harness.goProjectsHome();
    await harness.selectMoreMenuItem('制作工作区');
    await harness.capture('production_workspace');

    await harness.goProjectsHome();
    await harness.tapTooltip('帮助');
    await harness.capture('help_hub_webhooks');

    await harness.goProjectsHome();
    await harness.tapCreateProjectWizard(openOnly: true);
    await harness.capture('create_project_wizard_step_basics');
    await harness.advanceWizardBasics(projectName: 'E2E图库向导预览');
    await harness.capture('create_project_wizard_step_content');
    await harness.tapText('下一步');
    await harness.capture('create_project_wizard_step_review');
    await harness.closeOverlay();

    final projectName = 'E2E全量图库-${DateTime.now().millisecondsSinceEpoch}';
    await harness.goProjectsHome();
    if (await harness.tryCreateProjectViaWizard(projectName)) {
      await harness.capture('projects_with_seed_project');
      if (await harness.tryOpenProjectByName(projectName)) {
        await harness.assertProjectStudioEntered();
        await harness.capture('studio_step_script');
        await harness.tryCaptureStudioArtStep();
        await harness.tryCaptureStudioStep('4. 分镜', 'storyboard_studio_step');
        await harness.exitProjectStudio();
      }
    }

    await harness.goProjectsHome();
    await harness.capture('product_shell_chrome');

    final pngs = harness.listCapturedPngs();
    expect(
      pngs.length,
      greaterThanOrEqualTo(25),
      reason: 'expected ≥25 PNGs under ${harness.outputDir}, got ${pngs.length}',
    );
    expect(pngs.last.existsSync(), isTrue);
    print('E2E_GALLERY_DIR=${harness.outputDir}');
    print('E2E_GALLERY_COUNT=${pngs.length}');
  });
}

extension _RealProductShellGalleryFlows on RealProductShellGalleryHarness {
  Future<void> tapText(String label) async {
    await tester.tap(find.text(label));
    await pumpFrames(count: 12);
  }

  Future<void> tapCreateProjectWizard({bool openOnly = false}) async {
    final create = find.text('新建项目');
    expect(create, findsWidgets);
    await tester.tap(create.last, warnIfMissed: false);
    await waitFor(find.text('创建项目'));
    if (openOnly) {
      return;
    }
  }

  Future<void> advanceWizardBasics({required String projectName}) async {
    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    await tester.enterText(fields.first, projectName);
    await tapText('下一步');
    await pumpFrames();
  }
}
