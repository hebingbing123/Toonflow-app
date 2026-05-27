import 'package:flutter/material.dart';

import '../../../design_system/components/studio_dense_action_row.dart';
import '../../../design_system/components/studio_surfaces.dart';
import '../../../design_system/tokens.dart';
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
  final l10n = resolveAppLocalizationsForErrors(ctx);
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
    padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
    decoration: studioInsetPanelDecoration(ctx),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorNovelsEventsWorkbenchTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          first == null
              ? l10n.projectEditorNovelsEventsWorkbenchEmptyDetail
              : l10n.projectEditorNovelsEventsWorkbenchSummaryFirst(
                  summaryLine,
                  first.numericId,
                  first.name,
                ),
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: studioPanelMutedColor(ctx),
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(ctx),
              onPressed: disabled ? null : openWorkbench,
              child: Text(l10n.projectEditorNovelsEventsOpenWorkbench),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(ctx),
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
