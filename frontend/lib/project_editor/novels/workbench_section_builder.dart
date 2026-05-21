import 'package:flutter/material.dart';

import '../../../design_system/components/studio_surfaces.dart';
import '../../../design_system/components/studio_text_styles.dart';
import '../../../design_system/tokens.dart';
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
  final summaryLine = summarizeNovelRows(l10n, novels);
  final intakeSummaryLine = summarizeNovelIntakeRows(l10n, novels);
  final disabled =
      novelsBusy[0] ||
      novelsLoading[0] ||
      assetsBusy[0] ||
      assetsLoading[0] ||
      assetsScriptFilterLoading[0];

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
    decoration: studioInsetPanelDecoration(ctx),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorNovelsChapterWorkbenchTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.projectEditorNovelsWorkbenchStudioCrossLink,
          style: studioHintStyle(ctx),
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
          style: studioHintStyle(ctx),
        ),
        if (novels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            intakeSummaryLine,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(ctx).textSecondary,
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
