import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
Future<List<String>> listActiveRiskyOperationConfirmDontShowLabels() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final labels = <String>[];
    if (prefs.getBool(RiskyOperationConfirmPreferenceKeys.deleteVersion) ??
        false) {
      labels.add('删除成片版本');
    }
    if (prefs.getBool(RiskyOperationConfirmPreferenceKeys.batchDisable) ??
        false) {
      labels.add('批量禁用镜头');
    }
    if (prefs.getBool(RiskyOperationConfirmPreferenceKeys.restoreDraft) ??
        false) {
      labels.add('恢复草稿覆盖');
    }
    if (prefs.getBool(RiskyOperationConfirmPreferenceKeys.cancelExport) ??
        false) {
      labels.add('取消成片导出');
    }
    if (prefs.getBool(
          RiskyOperationConfirmPreferenceKeys.batchArchivePublish,
        ) ??
        false) {
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
Future<bool?> showResetRiskyOperationConfirmPrefsDialog(
  BuildContext context,
) async {
  final active = await listActiveRiskyOperationConfirmDontShowLabels();

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
                active.isEmpty
                    ? '当前无已保存的「不再提示」条目。仍可清除可能的残留键。'
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
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        '已清除本机高风险操作的「不再提示」偏好；后续将重新弹出确认。',
      ),
    ),
  );
}
