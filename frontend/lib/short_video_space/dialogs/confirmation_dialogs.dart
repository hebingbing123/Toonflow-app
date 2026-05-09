import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Preference keys for "don't show again" settings
class ConfirmationPreferenceKeys {
  static const String deleteVersion = 'confirmDeleteVersion';
  static const String batchDisable = 'confirmBatchDisable';
  static const String restoreDraft = 'confirmRestoreDraft';
  static const String cancelExport = 'confirmCancelExport';
  static const String batchArchivePublish = 'confirmBatchArchivePublish';
}

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
      final dontShow = prefs.getBool(ConfirmationPreferenceKeys.deleteVersion) ?? false;
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
      final dontShow = prefs.getBool(ConfirmationPreferenceKeys.batchDisable) ?? false;
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
      final dontShow = prefs.getBool(ConfirmationPreferenceKeys.restoreDraft) ?? false;
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
      final dontShow = prefs.getBool(ConfirmationPreferenceKeys.cancelExport) ?? false;
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
    builder: (ctx) => _CancelExportConfirmationDialog(
      showDontShowAgain: showDontShowAgain,
    ),
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

/// Reset all "don't show again" preferences
Future<void> resetAllConfirmationPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(ConfirmationPreferenceKeys.deleteVersion);
  await prefs.remove(ConfirmationPreferenceKeys.batchDisable);
  await prefs.remove(ConfirmationPreferenceKeys.restoreDraft);
  await prefs.remove(ConfirmationPreferenceKeys.cancelExport);
  await prefs.remove(ConfirmationPreferenceKeys.batchArchivePublish);
}

/// Human-readable snapshot of stored "don't show again" toggles (for ops UI).
Future<List<String>> listActiveConfirmationDontShowAgainLabels() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final labels = <String>[];
    if (prefs.getBool(ConfirmationPreferenceKeys.deleteVersion) ?? false) {
      labels.add('删除成片版本');
    }
    if (prefs.getBool(ConfirmationPreferenceKeys.batchDisable) ?? false) {
      labels.add('批量禁用镜头');
    }
    if (prefs.getBool(ConfirmationPreferenceKeys.restoreDraft) ?? false) {
      labels.add('恢复草稿覆盖');
    }
    if (prefs.getBool(ConfirmationPreferenceKeys.cancelExport) ?? false) {
      labels.add('取消成片导出');
    }
    if (prefs.getBool(ConfirmationPreferenceKeys.batchArchivePublish) ?? false) {
      labels.add('批量归档发布草稿');
    }
    return labels;
  } catch (_) {
    return [];
  }
}

/// Confirm clearing all local "don't show again" confirmations (platform recovery).
///
/// Returns `true` if user confirms reset.
Future<bool?> showResetConfirmationDontShowAgainDialog(
  BuildContext context,
) async {
  final active = await listActiveConfirmationDontShowAgainLabels();

  if (!context.mounted) {
    return null;
  }

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('恢复快风险确认框'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '将清除本机「不再提示」记录。此后删除版本、归档、取消导出等操作'
                '会重新弹出确认（仅影响当前设备上的本应用）。',
              ),
              const SizedBox(height: 12),
              Text(
                active.isEmpty ? '当前无已保存的「不再提示」条目。仍可清除可能的残留键。'
                    : '当前已静默确认的项目：',
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
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除并恢复'),
          ),
        ],
      );
    },
  );
}

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
    return AlertDialog(
      title: const Text('确认删除'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '确定要删除版本 "${widget.versionName}" 吗？\n\n'
            '此操作无法撤销。',
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
              title: const Text('不再提示'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: false, dontShowAgain: false),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('删除'),
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
    return AlertDialog(
      title: const Text('确认批量禁用'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '确定要禁用选中的 ${widget.shotCount} 个镜头吗？\n\n'
            '禁用后的镜头将不会出现在最终视频中。',
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
              title: const Text('不再提示'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: false, dontShowAgain: false),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          child: const Text('确认禁用'),
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
    return AlertDialog(
      title: const Text('确认恢复草稿'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '确定要恢复草稿 "${widget.draftName}" 吗？\n\n'
            '当前未保存的编辑状态将会丢失。',
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
              title: const Text('不再提示'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: false, dontShowAgain: false),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          child: const Text('恢复'),
        ),
      ],
    );
  }
}

class _CancelExportConfirmationDialog extends StatefulWidget {
  final bool showDontShowAgain;

  const _CancelExportConfirmationDialog({
    required this.showDontShowAgain,
  });

  @override
  State<_CancelExportConfirmationDialog> createState() =>
      _CancelExportConfirmationDialogState();
}

class _CancelExportConfirmationDialogState
    extends State<_CancelExportConfirmationDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('取消导出'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('确定要取消导出吗？已处理的内容将会丢失。'),
          if (widget.showDontShowAgain) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _dontShowAgain,
              onChanged: (value) {
                setState(() {
                  _dontShowAgain = value ?? false;
                });
              },
              title: const Text('不再提示'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: false, dontShowAgain: false),
          ),
          child: const Text('继续导出'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          child: const Text('确认取消'),
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
    return AlertDialog(
      title: const Text('批量归档确认'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '确定要归档 ${widget.draftCount} 张发布草稿吗？归档后将从待发布队列中移除（视后端策略可能可恢复）。',
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
              title: const Text('不再提示'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: false, dontShowAgain: false),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ConfirmationResult(confirmed: true, dontShowAgain: _dontShowAgain),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          child: const Text('确认归档'),
        ),
      ],
    );
  }
}
