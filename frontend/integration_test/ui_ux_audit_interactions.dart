// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_primary_button.dart';
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

  await harness.exitProjectStudio();
  await harness.ensureAuditShellReady();

  Future<void> runOverlayStep(String label, Future<void> Function() step) async {
    try {
      await step();
    } catch (e, st) {
      print('E2E_AUDIT_OVERLAY_STEP_FAIL=$label error=$e');
      print(st);
      await harness.closeOverlay();
      await harness.ensureAuditShellReady();
    } finally {
      await harness.recoverAuditNavigationAnchor();
    }
  }

  // —— 新建项目：BottomSheet 向导 ——
  await runOverlayStep('create_project_wizard', () async {
    await harness.goProjectsHome();
    if (!await harness.tryTapCreateProjectWizard(openOnly: true)) {
      return;
    }
    await harness.captureInteraction('create_project_wizard_open');
    await harness.closeOverlay();
    await harness.goProjectsHome();
  });

  // —— 「更多」菜单 ——
  await runOverlayStep('more_menu', () async {
    await harness.goProjectsHome();
    await harness.openMoreMenu();
    await harness.captureInteraction('more_menu_panel');
    await harness.closeMoreMenuIfOpen();
    await harness.ensureAuditShellReady();
  });

  // —— API 密钥：创建 Dialog ——
  await runOverlayStep('api_keys', () async {
  if (!await harness.navigateToUtilityPane(ProductWorkspacePane.apiKeys)) {
    return;
  }
    await harness.pumpFrames(count: 20);
    await harness.tryTapForOverlayI18n(<String>[
      '创建 API 密钥',
      'Create API key',
      '创建密钥',
    ], 'api_keys_create_dialog');
    await harness.closeOverlay();
    await harness.goProjectsHome();
  });

  await runOverlayStep('content_compliance', () async {
    if (!await harness.navigateToUtilityPane(
      ProductWorkspacePane.contentCompliance,
    )) {
      return;
    }
    await harness.pumpFrames(count: 20);
    await harness.captureInteraction('content_compliance_pane');
    await harness.goProjectsHome();
  });

  await runOverlayStep('help_hub', () async {
    if (!await harness.tryOpenHelpHubPane()) {
      return;
    }
    await harness.pumpFrames(count: 20);
    await harness.tryTapForOverlayI18n(<String>[
      '添加 Webhook',
      'Add webhook',
      '新建 Webhook',
    ], 'help_hub_add_webhook');
    await harness.captureInteraction('help_hub_pane');
    await harness.goProjectsHome();
  });

  await runOverlayStep('platform_config', () async {
    if (!await harness.navigateToUtilityPane(
      ProductWorkspacePane.platformConfig,
    )) {
      return;
    }
    await harness.pumpFrames(count: 20);
    await harness.tryTapForOverlayI18n(<String>[
      '添加供应商',
      'Add vendor',
      '连接供应商',
    ], 'platform_config_vendor_dialog');
    await harness.goProjectsHome();
  });

  await runOverlayStep('task_center', () async {
    if (!await harness.navigateToUtilityPane(ProductWorkspacePane.tasks)) {
      return;
    }
    await harness.refreshTaskCenterIfPossible();
    await harness.pumpFrames(count: 24);
    await harness.tryCaptureCollapsibleFilter('task_center');
    await harness.goProjectsHome();
  });

  await runOverlayStep('short_video', () async {
    if (!await harness.navigateToUtilityPane(
      ProductWorkspacePane.shortVideoSpace,
    )) {
      return;
    }
    await harness.pumpFrames(count: 24);
    await harness.tryTapForOverlayI18n(<String>[
      '筛选',
      'Filter',
      '过滤器',
    ], 'short_video_filter_panel');
    await harness.tryCaptureCollapsibleFilter('short_video');
    await harness.captureInteraction('short_video_space_pane');
    await harness.goProjectsHome();
  });

  await runOverlayStep('notifications', () async {
    if (!await harness.navigateToUtilityPane(
      ProductWorkspacePane.notifications,
    )) {
      return;
    }
    await harness.pumpFrames(count: 20);
    await harness.tryTapForOverlayI18n(<String>[
      '筛选',
      'Filter',
      '通知设置',
    ], 'notifications_filter_dialog');
    await harness.tryCaptureCollapsibleFilter('notifications');
    await harness.captureInteraction('notifications_pane');
    await harness.goProjectsHome();
  });

  await runOverlayStep('journey_workflow_dialog', () async {
    if (!await harness.tryOpenSeedProjectStudioViaRoute()) {
      return;
    }
    await harness.pumpFrames(count: 20);
    if (!await harness.tryOpenCreatorJourneyWorkflowDialog()) {
      return;
    }
    await harness.captureInteraction('journey_workflow_dialog');
    await harness.closeOverlay();
    await harness.exitProjectStudio();
    await harness.goProjectsHome();
  });

  await runOverlayStep('art_brief_sheet', () async {
    if (!await harness.tryOpenSeedProjectStudioViaRoute()) {
      return;
    }
    await harness.goStudioStepSlug('art');
    await harness.pumpFrames(count: 20);
    if (!await harness.tryOpenArtStepBriefSheet()) {
      await harness.exitProjectStudio();
      return;
    }
    await harness.captureInteraction('art_brief_sheet');
    await harness.closeOverlay();
    await harness.exitProjectStudio();
    await harness.goProjectsHome();
  });

  await runOverlayStep('script_setup_sheet_close', () async {
    if (!await harness.tryOpenSeedProjectStudioViaRoute()) {
      return;
    }
    await harness.goStudioStepSlug('script');
    await harness.pumpFrames(count: 20);
    if (!await harness.tryOpenScriptSetupSheetOverlay()) {
      await harness.exitProjectStudio();
      return;
    }
    await harness.captureInteraction('script_setup_sheet');
    await harness.closeOverlay();
    await harness.pumpFrames(count: 12);
    expect(find.text('新建项目').evaluate().isNotEmpty ||
        find.text('你的项目').evaluate().isNotEmpty ||
        find.text('New project').evaluate().isNotEmpty, isTrue);
    await harness.exitProjectStudio();
    await harness.goProjectsHome();
  });

  await runOverlayStep('more_menu_narrow', () async {
    await harness.goProjectsHome();
    await harness.openMoreMenu();
    await harness.captureInteraction('more_menu_web_375');
    await harness.closeMoreMenuIfOpen();
    await harness.ensureAuditShellReady();
  });

  await runOverlayStep('global_search_filter', () async {
    if (!await harness.tryOpenGlobalSearchFilterSheet()) {
      return;
    }
    await harness.captureInteraction('global_search_filter');
    await harness.closeOverlay();
    await harness.goProjectsHome();
  });

  await runOverlayStep('seed_project_studio', () async {
    await harness.goProjectsHome();
    await harness.tryCaptureSeedProjectStudioInteractions();
  });
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
        await harness.settleShell();
      },
      label: 'seed_project_studio_routes',
      timeout: const Duration(seconds: 45),
    );
  }

  await harness.goProjectsHome();
  await harness.capture('product_shell_chrome');

  await captureInteractionOverlays(harness);
  await harness.settleShell();
  await harness.writeAuditManifest();
}

extension _UiUxAuditGalleryFlows on RealProductShellGalleryHarness {
  Future<bool> tryTapCreateProjectWizard({bool openOnly = false}) async {
    await recoverAuditNavigationAnchor();
    for (final label in <String>['新建项目', 'New project']) {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        continue;
      }
      try {
        await tester.ensureVisible(finder.last);
      } catch (_) {}
      await tester.tap(finder.last, warnIfMissed: false);
      final titleZh = find.text('创建项目');
      final titleEn = find.text('Create project');
      await waitFor(titleZh.evaluate().isNotEmpty ? titleZh : titleEn);
      return true;
    }
    final primaryButtons = find.byType(StudioPrimaryButton);
    if (primaryButtons.evaluate().isEmpty) {
      return false;
    }
    await tester.tap(primaryButtons.last, warnIfMissed: false);
    final titleZh = find.text('创建项目');
    final titleEn = find.text('Create project');
    try {
      await waitFor(titleZh.evaluate().isNotEmpty ? titleZh : titleEn);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> tapCreateProjectWizard({bool openOnly = false}) async {
    final opened = await tryTapCreateProjectWizard(openOnly: openOnly);
    if (!opened) {
      throw TestFailure('No create-project button found');
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
