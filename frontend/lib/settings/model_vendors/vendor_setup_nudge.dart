import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/ix/studio_snackbar.dart';
import '../../design_system/ix/studio_toast_overlay.dart';
import '../../l10n/app_localizations.dart';
import '../../product_shell/studio_shell_branches.dart';
import '../../shell/navigation_controller.dart';
import '../../shell/studio_settings_hub_navigation.dart';
import 'domestic_vendor_setup_prefs.dart';
import 'domestic_vendors.dart';
import 'vendor_setup_loader.dart';

/// When/where to surface the domestic vendor API-key reminder.
enum VendorSetupNudgeTrigger { projectsHome, firstAiGenerate }

/// Projects-home + first-AI nudges (top-right glass on wide layouts).
class DomesticVendorSetupNudge {
  DomesticVendorSetupNudge._();

  static Future<bool> _needsNudge(String accessToken) async {
    if (await DomesticVendorSetupPrefs.isDismissed()) {
      return false;
    }
    final snapshot = await loadVendorCredentialSnapshot(accessToken);
    if (snapshot == null) {
      return false;
    }
    return !isDomesticVendorReadyForAiGeneration(
      snapshot.vendors,
      snapshot.credentialConfigured,
    );
  }

  static void _present(
    BuildContext context, {
    required VendorSetupNudgeTrigger trigger,
    required VoidCallback onOpenSettings,
  }) {
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    showStudioSnackBar(
      context,
      message: l10n.studioVendorSetupSnackMessage,
      icon: Icons.vpn_key_outlined,
      actionLabel: l10n.studioVendorSetupSnackAction,
      onAction: onOpenSettings,
      onDismiss: DomesticVendorSetupPrefs.markDismissed,
    );
    switch (trigger) {
      case VendorSetupNudgeTrigger.projectsHome:
        unawaited(DomesticVendorSetupPrefs.markHomeNudgeShown());
      case VendorSetupNudgeTrigger.firstAiGenerate:
        unawaited(DomesticVendorSetupPrefs.markAiNudgeShown());
    }
  }

  static void openModelVendorSettings(BuildContext context) {
    StudioSettingsHubNavigation.requestApiModelsTab();
    GoRouter.of(context).go(studioUriForUtilityPane(ProductWorkspacePane.account));
  }

  /// Once per install on the projects home grid (prefs-gated).
  static Future<void> maybeShowOnProjectsHome(
    BuildContext context, {
    required String accessToken,
    required VoidCallback onOpenSettings,
  }) async {
    if (!context.mounted) {
      return;
    }
    if (await DomesticVendorSetupPrefs.wasHomeNudgeShown()) {
      return;
    }
    if (!await _needsNudge(accessToken)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    _present(
      context,
      trigger: VendorSetupNudgeTrigger.projectsHome,
      onOpenSettings: onOpenSettings,
    );
  }

  /// Before an AI generate action: show once, return false to block the action.
  static Future<bool> guardBeforeAiGenerate(
    BuildContext context, {
    required String? accessToken,
    VoidCallback? onOpenSettings,
  }) async {
    final token = accessToken?.trim();
    if (token == null || token.isEmpty || !context.mounted) {
      return true;
    }
    if (!await _needsNudge(token)) {
      return true;
    }
    if (await DomesticVendorSetupPrefs.wasAiNudgeShown()) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    _present(
      context,
      trigger: VendorSetupNudgeTrigger.firstAiGenerate,
      onOpenSettings:
          onOpenSettings ?? () => openModelVendorSettings(context),
    );
    return false;
  }
}
