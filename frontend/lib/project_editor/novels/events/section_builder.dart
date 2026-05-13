import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../rust_api.dart';
import '../support.dart';

Widget buildProjectNovelEventsWorkbenchSection({
  required BuildContext ctx,
  required List<NovelEventRow> events,
  required List<bool> novelsLoading,
  required List<bool> novelsBusy,
  required List<bool> novelEventsLoading,
  required List<bool> assetsBusy,
  required List<bool> assetsLoading,
  required List<bool> assetsScriptFilterLoading,
  required Future<void> Function() openWorkbench,
  required Future<void> Function() refreshEvents,
}) {
  final l10n = AppLocalizations.of(ctx)!;
  final first = events.isNotEmpty ? events.first : null;
  final summaryLine = summarizeNovelEventRows(l10n, events);
  final disabled =
      novelsBusy[0] ||
      novelsLoading[0] ||
      novelEventsLoading[0] ||
      assetsBusy[0] ||
      assetsLoading[0] ||
      assetsScriptFilterLoading[0];

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(
        ctx,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorNovelsEventsWorkbenchTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          first == null
              ? l10n.projectEditorNovelsEventsWorkbenchEmptyDetail
              : l10n.projectEditorNovelsEventsWorkbenchSummaryFirst(
                  summaryLine,
                  first.numericId,
                  first.name,
                ),
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: disabled ? null : openWorkbench,
              child: Text(l10n.projectEditorNovelsEventsOpenWorkbench),
            ),
            OutlinedButton(
              onPressed: disabled ? null : refreshEvents,
              child: Text(
                novelEventsLoading[0]
                    ? l10n.projectEditorNovelsEventsRefreshing
                    : l10n.projectEditorNovelsEventsRefresh,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
