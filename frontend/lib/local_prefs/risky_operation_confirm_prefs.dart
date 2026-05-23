import 'dart:async';

import 'package:flutter/material.dart';
import '../design_system/tokens.dart';

import '../design_system/components/studio_dropdown_field.dart';
import '../design_system/components/studio_decorative_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/rust_api_error_format.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

/// SharedPreferences keys for client-side "don't show again" on destructive flows.
class RiskyOperationConfirmPreferenceKeys {
  static const String deleteVersion = 'confirmDeleteVersion';
  static const String batchDisable = 'confirmBatchDisable';
  static const String restoreDraft = 'confirmRestoreDraft';
  static const String cancelExport = 'confirmCancelExport';
  static const String batchArchivePublish = 'confirmBatchArchivePublish';
}

/// Reset all local risky-operation "don't show again" toggles.
Future<void> resetAllRiskyOperationConfirmPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(RiskyOperationConfirmPreferenceKeys.deleteVersion);
  await prefs.remove(RiskyOperationConfirmPreferenceKeys.batchDisable);
  await prefs.remove(RiskyOperationConfirmPreferenceKeys.restoreDraft);
  await prefs.remove(RiskyOperationConfirmPreferenceKeys.cancelExport);
  await prefs.remove(RiskyOperationConfirmPreferenceKeys.batchArchivePublish);
}

/// Labels for prefs that are currently true (for ops / recovery UI).
Future<List<String>> listActiveRiskyOperationConfirmDontShowLabels(
  AppLocalizations l10n,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final labels = <String>[];
    if (prefs.getBool(RiskyOperationConfirmPreferenceKeys.deleteVersion) ??
        false) {
      labels.add(l10n.riskyPrefsLabelDeleteVersion);
    }
    if (prefs.getBool(RiskyOperationConfirmPreferenceKeys.batchDisable) ??
        false) {
      labels.add(l10n.riskyPrefsLabelBatchDisable);
    }
    if (prefs.getBool(RiskyOperationConfirmPreferenceKeys.restoreDraft) ??
        false) {
      labels.add(l10n.riskyPrefsLabelRestoreDraft);
    }
    if (prefs.getBool(RiskyOperationConfirmPreferenceKeys.cancelExport) ??
        false) {
      labels.add(l10n.riskyPrefsLabelCancelExport);
    }
    if (prefs.getBool(
          RiskyOperationConfirmPreferenceKeys.batchArchivePublish,
        ) ??
        false) {
      labels.add(l10n.riskyPrefsLabelBatchArchivePublish);
    }
    return labels;
  } catch (_) {
    return [];
  }
}

/// Read-only summary: which destructive confirms are currently silenced on this device.
Future<void> showActiveRiskyOperationConfirmPrefsSummary(
  BuildContext context,
) async {
  final l10n = resolveAppLocalizationsForErrors(context);
  final active = await listActiveRiskyOperationConfirmDontShowLabels(l10n);
  if (!context.mounted) {
    return;
  }
  await showStudioDialog<void>(
    context: context,
    builder: (ctx) {
      final dl10n = resolveAppLocalizationsForErrors(ctx);
      return StudioAlertDialog(
        title: Text(dl10n.riskyPrefsSummaryDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active.isEmpty
                    ? dl10n.riskyPrefsSummaryEmptyBody
                    : dl10n.riskyPrefsSummaryNonEmptyIntro,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: StudioSpacing.sm),
                ...active.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(dl10n.riskyPrefsSummaryClose),
          ),
        ],
      );
    },
  );
}

/// Confirm clearing all local "don't show again" confirmations (platform recovery).
///
/// Returns `true` if user confirms reset.
Future<bool?> showResetRiskyOperationConfirmPrefsDialog(
  BuildContext context,
) async {
  final l10n = resolveAppLocalizationsForErrors(context);
  final active = await listActiveRiskyOperationConfirmDontShowLabels(l10n);

  if (!context.mounted) {
    return null;
  }

  return showStudioDialog<bool>(
    context: context,
    builder: (ctx) {
      final dl10n = resolveAppLocalizationsForErrors(ctx);
      return StudioAlertDialog(
        title: Text(dl10n.riskyPrefsResetDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dl10n.riskyPrefsResetBody),
              const SizedBox(height: StudioSpacing.sm),
              Text(
                active.isEmpty
                    ? dl10n.riskyPrefsResetNoSavedLabel
                    : dl10n.riskyPrefsResetHasItemsLabel,
                style: Theme.of(ctx).textTheme.labelMedium,
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...active.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(dl10n.riskyPrefsResetCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(dl10n.riskyPrefsResetConfirm),
          ),
        ],
      );
    },
  );
}

/// Dialog → clear prefs → SnackBar. Single entry for shell + feature surfaces.
Future<void> runResetRiskyOperationConfirmPrefsFlow(
  BuildContext context,
) async {
  final ok = await showResetRiskyOperationConfirmPrefsDialog(context);
  if (ok != true) {
    return;
  }
  await resetAllRiskyOperationConfirmPreferences();
  if (!context.mounted) {
    return;
  }
  final l10n = resolveAppLocalizationsForErrors(context);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.riskyPrefsResetSuccessSnack)));
}

enum _RiskyPrefsOverflowValue { viewActiveSilences, resetDestructiveConfirms }

/// AppBar / toolbar entry: **查看已静默** + **恢复确认**（本机 SharedPreferences）。
///
/// Use wherever the product shell needs a compact cross-cut without duplicating strings.
/// Keep the icon preference-specific so it does not read like a generic page overflow menu.
class RiskyOperationConfirmPrefsOverflowMenu extends StatelessWidget {
  const RiskyOperationConfirmPrefsOverflowMenu({
    super.key,
    this.icon = Icons.tune_rounded,
    this.tooltip,
  });

  final IconData icon;

  /// When null, uses [AppLocalizations.riskyPrefsMenuDefaultTooltip].
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioIconMenuButton<_RiskyPrefsOverflowValue>(
      tooltip: tooltip ?? l10n.riskyPrefsMenuDefaultTooltip,
      icon: icon,
      entries: <StudioMenuEntry<_RiskyPrefsOverflowValue>>[
        StudioMenuEntry<_RiskyPrefsOverflowValue>(
          value: _RiskyPrefsOverflowValue.viewActiveSilences,
          label: l10n.riskyPrefsMenuViewSilencesTitle,
          subtitle: l10n.riskyPrefsMenuViewSilencesSubtitle,
          leading: studioDecorativeIcon(
            Icons.visibility_outlined,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        StudioMenuEntry<_RiskyPrefsOverflowValue>(
          value: _RiskyPrefsOverflowValue.resetDestructiveConfirms,
          label: l10n.riskyPrefsMenuResetTitle,
          subtitle: l10n.riskyPrefsMenuResetSubtitle,
          leading: studioDecorativeIcon(Icons.notifications_active_outlined, size: 22),
        ),
      ],
      onSelected: (value) {
        if (value == _RiskyPrefsOverflowValue.viewActiveSilences) {
          unawaited(showActiveRiskyOperationConfirmPrefsSummary(context));
        } else if (value == _RiskyPrefsOverflowValue.resetDestructiveConfirms) {
          unawaited(runResetRiskyOperationConfirmPrefsFlow(context));
        }
      },
    );
  }
}
