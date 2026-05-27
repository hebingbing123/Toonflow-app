// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

import 'support/real_product_shell_gallery_support.dart';

/// Extra overlay / modal / sheet / expand-collapse captures (after route gallery).
Future<void> captureInteractionOverlays(
  RealProductShellGalleryHarness harness,
) async {
  try {
    await _captureInteractionOverlaysImpl(harness);
  } catch (e, st) {
    print('E2E_AUDIT_OVERLAY_WARN=$e');
    print(st);
  }
}

Future<void> _captureInteractionOverlaysImpl(
  RealProductShellGalleryHarness harness,
) async {
  // Skip global workbench dialogs (API-heavy, caused 30m+ stalls in audit).

  // —— 新建项目：BottomSheet 向导 ——
  await harness.goProjectsHome();
  try {
    await harness.tapCreateProjectWizard(openOnly: true);
    await harness.captureInteraction('create_project_wizard_open');
    await harness.closeOverlay();
  } catch (_) {
    await harness.closeOverlay();
  }

  // —— 「更多」菜单 ——
  await harness.goProjectsHome();
  await harness.openMoreMenu();
  await harness.captureInteraction('more_menu_panel');
  await harness.closeMoreMenuIfOpen();

  // —— API 密钥：创建 Dialog ——
  if (await harness.navigateToUtilityPane(ProductWorkspacePane.apiKeys)) {
    await harness.pumpFrames(count: 20);
    await harness.tryTapForOverlayI18n(<String>[
      '创建 API 密钥',
      'Create API key',
      '创建密钥',
    ], 'api_keys_create_dialog');
    await harness.closeOverlay();
    await harness.goProjectsHome();
  }

  // —— 内容合规（侧栏/队列态） ——
  if (await harness.navigateToUtilityPane(
    ProductWorkspacePane.contentCompliance,
  )) {
    await harness.pumpFrames(count: 20);
    await harness.captureInteraction('content_compliance_pane');
    await harness.goProjectsHome();
  }

  // —— 帮助 Hub ——
  if (await harness.tryOpenHelpHubPane()) {
    await harness.pumpFrames(count: 20);
    await harness.tryTapForOverlayI18n(<String>[
      '添加 Webhook',
      'Add webhook',
      '新建 Webhook',
    ], 'help_hub_add_webhook');
    await harness.captureInteraction('help_hub_pane');
    await harness.goProjectsHome();
  }

  // —— 平台配置：供应商 Dialog ——
  if (await harness.navigateToUtilityPane(
    ProductWorkspacePane.platformConfig,
  )) {
    await harness.pumpFrames(count: 20);
    await harness.tryTapForOverlayI18n(<String>[
      '添加供应商',
      'Add vendor',
      '连接供应商',
    ], 'platform_config_vendor_dialog');
    await harness.goProjectsHome();
  }

  // —— 任务中心：可折叠筛选 ——
  if (await harness.navigateToUtilityPane(ProductWorkspacePane.tasks)) {
    await harness.refreshTaskCenterIfPossible();
    await harness.pumpFrames(count: 24);
    await harness.tryCaptureCollapsibleFilter('task_center');
    await harness.goProjectsHome();
  }

  // —— 多平台分发：筛选面板 ——
  if (await harness.navigateToUtilityPane(
    ProductWorkspacePane.shortVideoSpace,
  )) {
    await harness.pumpFrames(count: 24);
    await harness.tryTapForOverlayI18n(<String>[
      '筛选',
      'Filter',
      '过滤器',
    ], 'short_video_filter_panel');
    await harness.tryCaptureCollapsibleFilter('short_video');
    await harness.captureInteraction('short_video_space_pane');
    await harness.goProjectsHome();
  }

  // —— 通知：筛选 / 设置 ——
  if (await harness.tryOpenNotificationsPane()) {
    await harness.pumpFrames(count: 20);
    await harness.tryTapForOverlayI18n(<String>[
      '筛选',
      'Filter',
      '通知设置',
    ], 'notifications_filter_dialog');
    await harness.tryCaptureCollapsibleFilter('notifications');
    await harness.captureInteraction('notifications_pane');
    await harness.goProjectsHome();
  }

  // —— 项目工作室：仅针对本 run 创建的种子项目 ——
  await harness.goProjectsHome();
  await harness.tryCaptureSeedProjectStudioInteractions();
}

/// Route gallery + interaction overlays (shared by audit test).
Future<void> captureFullGalleryRoutes(
  RealProductShellGalleryHarness harness,
) async {
  await harness.bootstrap();
  await harness.capture('login_default');
  await harness.login();
  await harness.capture('projects_default');

  if (await harness.tryOpenNotificationsPane()) {
    await harness.refreshNotificationsIfPossible();
    await harness.capture('notifications_studio');
    await harness.goProjectsHome();
  }

  if (await harness.tryOpenSettingsHubCompactAware()) {
    await harness.pumpFrames(count: 32);
    await harness.capture('settings_account');
    await harness.openSettingsTabByIndex(1);
    await harness.capture('settings_plan_usage');
    await harness.openSettingsTabByIndex(2);
    await harness.capture('settings_api');
    await harness.openSettingsTabByIndex(3);
    await harness.capture('settings_workspaces');
    await harness.goProjectsHome();
  }

  await harness.goProjectsHome();
  await harness.openMoreMenu();
  await harness.capture('more_menu');
  await harness.closeMoreMenuIfOpen();

  await harness.tryNavigateAndCapture(
    'tasks_default',
    ProductWorkspacePane.tasks,
    afterNavigate: harness.refreshTaskCenterIfPossible,
  );

  await harness.tryNavigateAndCapture(
    'quality_default',
    ProductWorkspacePane.quality,
  );

  await harness.tryNavigateAndCapture(
    'jobs_default',
    ProductWorkspacePane.jobs,
  );

  await harness.tryNavigateAndCapture(
    'short_video_overview',
    ProductWorkspacePane.shortVideoSpace,
  );

  await harness.tryNavigateAndCapture(
    'team_workspaces',
    ProductWorkspacePane.teamWorkspaces,
  );

  await harness.tryNavigateAndCapture(
    'settings_api_keys_pane',
    ProductWorkspacePane.apiKeys,
  );

  await harness.tryNavigateAndCapture(
    'content_compliance_queue',
    ProductWorkspacePane.contentCompliance,
  );

  await harness.tryNavigateAndCapture(
    'platform_status',
    ProductWorkspacePane.platformStatus,
  );

  await harness.tryNavigateAndCapture(
    'platform_config',
    ProductWorkspacePane.platformConfig,
  );

  await harness.tryNavigateAndCapture(
    'script_workspace',
    ProductWorkspacePane.scriptWorkspace,
  );

  await harness.tryNavigateAndCapture(
    'production_workspace',
    ProductWorkspacePane.productionWorkspace,
  );

  await harness.tryNavigateAndCapture(
    'help_hub_webhooks',
    ProductWorkspacePane.helpHub,
  );

  await harness.goProjectsHome();
  try {
    await harness.tapCreateProjectWizard(openOnly: true);
    await harness.capture('create_project_wizard_step_basics');
    await harness.advanceWizardBasics(projectName: 'E2E图库向导预览');
    await harness.capture('create_project_wizard_step_content');
    await harness.tapWizardActionI18n(<String>['下一步', 'Next']);
    await harness.capture('create_project_wizard_step_review');
    await harness.closeOverlay();
  } catch (_) {
    await harness.closeOverlay();
    await harness.goProjectsHome();
  }

  final projectName = 'E2E审计-${DateTime.now().millisecondsSinceEpoch}';
  await harness.goProjectsHome();
  if (await harness.withAuditTimeout(
    () async {
      if (await harness.tryCreateSeedProjectViaApi(projectName)) {
        return;
      }
      if (!await harness.tryCreateProjectViaWizard(projectName)) {
        throw TestFailure('seed project failed (API + wizard)');
      }
    },
    label: 'seed_project_create',
    timeout: const Duration(seconds: 45),
  )) {
    await harness.capture('projects_with_seed_project');
    await harness.withAuditTimeout(
      () async {
        if (!await harness.tryOpenSeedProjectStudioViaRoute()) {
          throw TestFailure('seed project open failed');
        }
        await harness.capture('studio_step_script');
        await harness.tryCaptureStudioArtStep();
        await harness.tryCaptureStudioStep('4. 分镜', 'storyboard_studio_step');
        await harness.exitProjectStudio();
        await harness.goProjectsHome();
      },
      label: 'seed_project_studio_routes',
      timeout: const Duration(seconds: 45),
    );
  }

  await harness.goProjectsHome();
  await harness.capture('product_shell_chrome');

  await captureInteractionOverlays(harness);
  await harness.writeAuditManifest();
}

extension _UiUxAuditGalleryFlows on RealProductShellGalleryHarness {
  Future<void> tapCreateProjectWizard({bool openOnly = false}) async {
    final create = find.text('新建项目');
    final createEn = find.text('New project');
    if (create.evaluate().isEmpty && createEn.evaluate().isEmpty) {
      throw TestFailure('No create-project button found');
    }
    final target = create.evaluate().isNotEmpty ? create : createEn;
    await tester.tap(target.last, warnIfMissed: false);
    final titleZh = find.text('创建项目');
    final titleEn = find.text('Create project');
    await waitFor(titleZh.evaluate().isNotEmpty ? titleZh : titleEn);
    if (openOnly) {
      return;
    }
  }

  Future<void> advanceWizardBasics({required String projectName}) async {
    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    await tester.enterText(fields.first, projectName);
    await tapWizardActionI18n(<String>['下一步', 'Next']);
    await pumpFrames();
  }
}
