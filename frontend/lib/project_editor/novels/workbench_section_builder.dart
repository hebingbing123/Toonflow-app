import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../rust_api.dart';
import 'support.dart';

Widget buildProjectNovelsWorkbenchSection({
  required BuildContext ctx,
  required AppLocalizations l10n,
  required List<NovelRow> novels,
  required List<bool> novelsLoading,
  required List<bool> novelsBusy,
  required List<bool> assetsBusy,
  required List<bool> assetsLoading,
  required List<bool> assetsScriptFilterLoading,
  required VoidCallback openWorkbench,
  required Future<void> Function() refreshNovels,
  required Future<void> Function() generateEvents,
}) {
  final first = novels.isNotEmpty ? novels.first : null;
  final last = novels.isNotEmpty ? novels.last : null;
  final summaryLine = summarizeNovelRows(novels);
  final intakeSummaryLine = summarizeNovelIntakeRows(novels);
  final disabled =
      novelsBusy[0] ||
      novelsLoading[0] ||
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
          l10n.projectEditorNovelsChapterWorkbenchTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          first == null
              ? l10n.projectEditorNovelsWorkbenchCardSummaryEmptyHelp
              : l10n.projectEditorNovelsWorkbenchCardSummaryDualBounds(
                  summaryLine,
                  first.numericId,
                  first.chapter,
                  last!.numericId,
                  last.chapter,
                ),
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        if (novels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            intakeSummaryLine,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: disabled ? null : openWorkbench,
              child: Text(l10n.projectEditorNovelsWorkbenchCardOpenButton),
            ),
            OutlinedButton(
              onPressed: disabled ? null : () => refreshNovels(),
              child: Text(
                novelsLoading[0]
                    ? l10n.projectEditorNovelsWorkbenchCardRefreshChaptersBusy
                    : l10n.projectEditorNovelsWorkbenchCardRefreshChapters,
              ),
            ),
            OutlinedButton(
              onPressed: disabled || novels.isEmpty
                  ? null
                  : () => generateEvents(),
              child: Text(
                l10n.projectEditorNovelsWorkbenchCardGenerateEventsForTopThree,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
