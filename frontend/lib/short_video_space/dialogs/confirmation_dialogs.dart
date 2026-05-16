import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../local_prefs/risky_operation_confirm_prefs.dart';
import '../../rust_api.dart';

/// Confirmation dialog utilities for short video editing operations
///
/// Provides reusable confirmation dialogs with "Don't show again" functionality
/// for destructive or important operations.
///
/// **Validates: Requirements 28**

/// Result of a confirmation dialog with "don't show again" option
class ConfirmationResult {
  final bool confirmed;
  final bool dontShowAgain;

  const ConfirmationResult({
    required this.confirmed,
    required this.dontShowAgain,
  });
}

/// Preference keys for "don't show again" settings (short-video destructive flows).
///
/// Prefer [RiskyOperationConfirmPreferenceKeys] for new code; this alias keeps
/// imports stable under `confirmation_dialogs.dart`.
typedef ConfirmationPreferenceKeys = RiskyOperationConfirmPreferenceKeys;

/// Show confirmation dialog for deleting a version
///
/// Returns true if confirmed, false if cancelled or null if dismissed
Future<bool?> showDeleteVersionConfirmation(
  BuildContext context, {
  required String versionName,
  bool showDontShowAgain = false,
}) async {
  // Check if user has disabled this confirmation
  if (showDontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dontShow =
          prefs.getBool(RiskyOperationConfirmPreferenceKeys.deleteVersion) ??
          false;
      if (dontShow) {
        return true; // Auto-confirm if user chose "don't show again"
      }
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  if (!context.mounted) return null;

  final result = await showDialog<ConfirmationResult>(
    context: context,
    builder: (ctx) => _DeleteVersionConfirmationDialog(
      versionName: versionName,
      showDontShowAgain: showDontShowAgain,
    ),
  );

  if (result != null && result.dontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ConfirmationPreferenceKeys.deleteVersion, true);
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  return result?.confirmed;
}

/// Show confirmation dialog for batch disabling shots
///
/// Returns true if confirmed, false if cancelled or null if dismissed
Future<bool?> showBatchDisableConfirmation(
  BuildContext context, {
  required int shotCount,
  bool showDontShowAgain = false,
}) async {
  // Check if user has disabled this confirmation
  if (showDontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dontShow =
          prefs.getBool(ConfirmationPreferenceKeys.batchDisable) ?? false;
      if (dontShow) {
        return true; // Auto-confirm if user chose "don't show again"
      }
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  if (!context.mounted) return null;

  final result = await showDialog<ConfirmationResult>(
    context: context,
    builder: (ctx) => _BatchDisableConfirmationDialog(
      shotCount: shotCount,
      showDontShowAgain: showDontShowAgain,
    ),
  );

  if (result != null && result.dontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ConfirmationPreferenceKeys.batchDisable, true);
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  return result?.confirmed;
}

/// Show confirmation dialog for restoring a draft
///
/// Returns true if confirmed, false if cancelled or null if dismissed
Future<bool?> showRestoreDraftConfirmation(
  BuildContext context, {
  required String draftName,
  bool showDontShowAgain = false,
}) async {
  // Check if user has disabled this confirmation
  if (showDontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dontShow =
          prefs.getBool(ConfirmationPreferenceKeys.restoreDraft) ?? false;
      if (dontShow) {
        return true; // Auto-confirm if user chose "don't show again"
      }
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  if (!context.mounted) return null;

  final result = await showDialog<ConfirmationResult>(
    context: context,
    builder: (ctx) => _RestoreDraftConfirmationDialog(
      draftName: draftName,
      showDontShowAgain: showDontShowAgain,
    ),
  );

  if (result != null && result.dontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ConfirmationPreferenceKeys.restoreDraft, true);
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  return result?.confirmed;
}

/// Show confirmation dialog for cancelling an export
///
/// Returns true if confirmed, false if cancelled or null if dismissed
Future<bool?> showCancelExportConfirmation(
  BuildContext context, {
  bool showDontShowAgain = false,
}) async {
  // Check if user has disabled this confirmation
  if (showDontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dontShow =
          prefs.getBool(ConfirmationPreferenceKeys.cancelExport) ?? false;
      if (dontShow) {
        return true; // Auto-confirm if user chose "don't show again"
      }
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  if (!context.mounted) return null;

  final result = await showDialog<ConfirmationResult>(
    context: context,
    builder: (ctx) =>
        _CancelExportConfirmationDialog(showDontShowAgain: showDontShowAgain),
  );

  if (result != null && result.dontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ConfirmationPreferenceKeys.cancelExport, true);
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  return result?.confirmed;
}

/// Confirm batch-archiving publish drafts (destructive for the publish pipeline).
///
/// Returns true if confirmed, false if cancelled, or null if dismissed.
Future<bool?> showBatchArchivePublishConfirmation(
  BuildContext context, {
  required int draftCount,
  bool showDontShowAgain = false,
}) async {
  if (showDontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dontShow =
          prefs.getBool(ConfirmationPreferenceKeys.batchArchivePublish) ??
          false;
      if (dontShow) {
        return true;
      }
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  if (!context.mounted) return null;

  final result = await showDialog<ConfirmationResult>(
    context: context,
    builder: (ctx) => _BatchArchivePublishConfirmationDialog(
      draftCount: draftCount,
      showDontShowAgain: showDontShowAgain,
    ),
  );

  if (result != null && result.dontShowAgain) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(ConfirmationPreferenceKeys.batchArchivePublish, true);
    } catch (e) {
      // Ignore SharedPreferences errors (e.g., in tests)
    }
  }

  return result?.confirmed;
}

/// Reset all "don't show again" preferences (delegates to platform-local prefs).
Future<void> resetAllConfirmationPreferences() =>
    resetAllRiskyOperationConfirmPreferences();

/// Human-readable snapshot of stored "don't show again" toggles (for ops UI).
Future<List<String>> listActiveConfirmationDontShowAgainLabels(
  AppLocalizations l10n,
) => listActiveRiskyOperationConfirmDontShowLabels(l10n);

/// Read-only dialog listing current silenced confirms (delegates to platform prefs).
Future<void> showActiveConfirmationDontShowAgainSummary(BuildContext context) =>
    showActiveRiskyOperationConfirmPrefsSummary(context);

/// Confirm clearing all local "don't show again" confirmations (platform recovery).
Future<bool?> showResetConfirmationDontShowAgainDialog(BuildContext context) =>
    showResetRiskyOperationConfirmPrefsDialog(context);

// Private dialog widgets

class _DeleteVersionConfirmationDialog extends StatefulWidget {
  final String versionName;
  final bool showDontShowAgain;

  const _DeleteVersionConfirmationDialog({
    required this.versionName,
    required this.showDontShowAgain,
  });

  @override
  State<_DeleteVersionConfirmationDialog> createState() =>
      _DeleteVersionConfirmationDialogState();
}

class _DeleteVersionConfirmationDialogState
    extends State<_DeleteVersionConfirmationDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return AlertDialog(
      title: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shortVideoSpaceDialogConfirmDeleteVersionMessage(widget.versionName),
          ),
          if (widget.showDontShowAgain) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _dontShowAgain,
              onChanged: (value) {
                setState(() {
                  _dontShowAgain = value ?? false;
                });
              },
              title: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionDontShow),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ConfirmationResult(confirmed: false, dontShowAgain: false)),
          child: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionConfirm),
        ),
      ],
    );
  }
}

class _BatchDisableConfirmationDialog extends StatefulWidget {
  final int shotCount;
  final bool showDontShowAgain;

  const _BatchDisableConfirmationDialog({
    required this.shotCount,
    required this.showDontShowAgain,
  });

  @override
  State<_BatchDisableConfirmationDialog> createState() =>
      _BatchDisableConfirmationDialogState();
}

class _BatchDisableConfirmationDialogState
    extends State<_BatchDisableConfirmationDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return AlertDialog(
      title: Text(l10n.shortVideoSpaceDialogConfirmBatchDisableTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shortVideoSpaceDialogConfirmBatchDisableMessage(widget.shotCount),
          ),
          if (widget.showDontShowAgain) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _dontShowAgain,
              onChanged: (value) {
                setState(() {
                  _dontShowAgain = value ?? false;
                });
              },
              title: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionDontShow),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ConfirmationResult(confirmed: false, dontShowAgain: false)),
          child: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          child: Text(l10n.shortVideoSpaceDialogConfirmBatchDisableConfirm),
        ),
      ],
    );
  }
}

class _RestoreDraftConfirmationDialog extends StatefulWidget {
  final String draftName;
  final bool showDontShowAgain;

  const _RestoreDraftConfirmationDialog({
    required this.draftName,
    required this.showDontShowAgain,
  });

  @override
  State<_RestoreDraftConfirmationDialog> createState() =>
      _RestoreDraftConfirmationDialogState();
}

class _RestoreDraftConfirmationDialogState
    extends State<_RestoreDraftConfirmationDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return AlertDialog(
      title: Text(l10n.shortVideoSpaceDialogConfirmRestoreDraftTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shortVideoSpaceDialogConfirmRestoreDraftMessage(widget.draftName),
          ),
          if (widget.showDontShowAgain) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _dontShowAgain,
              onChanged: (value) {
                setState(() {
                  _dontShowAgain = value ?? false;
                });
              },
              title: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionDontShow),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ConfirmationResult(confirmed: false, dontShowAgain: false)),
          child: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          child: Text(l10n.shortVideoSpaceDialogConfirmRestoreDraftConfirm),
        ),
      ],
    );
  }
}

class _CancelExportConfirmationDialog extends StatefulWidget {
  final bool showDontShowAgain;

  const _CancelExportConfirmationDialog({required this.showDontShowAgain});

  @override
  State<_CancelExportConfirmationDialog> createState() =>
      _CancelExportConfirmationDialogState();
}

class _CancelExportConfirmationDialogState
    extends State<_CancelExportConfirmationDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return AlertDialog(
      title: Text(l10n.shortVideoSpaceDialogConfirmCancelExportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shortVideoSpaceDialogConfirmCancelExportMessage),
          if (widget.showDontShowAgain) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _dontShowAgain,
              onChanged: (value) {
                setState(() {
                  _dontShowAgain = value ?? false;
                });
              },
              title: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionDontShow),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ConfirmationResult(confirmed: false, dontShowAgain: false)),
          child: Text(l10n.shortVideoSpaceDialogConfirmCancelExportContinue),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          child: Text(l10n.shortVideoSpaceDialogConfirmCancelExportConfirm),
        ),
      ],
    );
  }
}

class _BatchArchivePublishConfirmationDialog extends StatefulWidget {
  const _BatchArchivePublishConfirmationDialog({
    required this.draftCount,
    required this.showDontShowAgain,
  });

  final int draftCount;
  final bool showDontShowAgain;

  @override
  State<_BatchArchivePublishConfirmationDialog> createState() =>
      _BatchArchivePublishConfirmationDialogState();
}

class _BatchArchivePublishConfirmationDialogState
    extends State<_BatchArchivePublishConfirmationDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return AlertDialog(
      title: Text(l10n.shortVideoSpaceDialogConfirmBatchArchiveTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.shortVideoSpaceDialogConfirmBatchArchiveMessage(widget.draftCount)),
          if (widget.showDontShowAgain) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _dontShowAgain,
              onChanged: (value) {
                setState(() {
                  _dontShowAgain = value ?? false;
                });
              },
              title: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionDontShow),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(ConfirmationResult(confirmed: false, dontShowAgain: false)),
          child: Text(l10n.shortVideoSpaceDialogConfirmDeleteVersionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: Text(l10n.shortVideoSpaceDialogConfirmBatchArchiveConfirm),
        ),
      ],
    );
  }
}
