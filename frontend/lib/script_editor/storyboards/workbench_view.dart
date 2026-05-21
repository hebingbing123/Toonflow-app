import 'package:flutter/material.dart';

import '../../../design_system/components/studio_empty_state.dart';
import '../../../design_system/components/studio_surfaces.dart';
import '../../../design_system/components/studio_text_styles.dart';
import '../../../design_system/tokens.dart';
import '../../../rust_api.dart';
import '../../storyboard_editor/support/diagnosis.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

class StoryboardsWorkbenchDialogViewModel {
  const StoryboardsWorkbenchDialogViewModel({
    required this.boardsList,
    required this.diagnosis,
    required this.productionSummaryLine,
    required this.storyboardTaskLine,
    required this.actionBusy,
    required this.boardsLoading,
    required this.productionSummaryLoading,
  });

  final List<StoryboardRow> boardsList;
  final StoryboardListDiagnosis diagnosis;
  final String? productionSummaryLine;
  final String? storyboardTaskLine;
  final bool actionBusy;
  final bool boardsLoading;
  final bool productionSummaryLoading;
}

class StoryboardsWorkbenchDialogViewCallbacks {
  const StoryboardsWorkbenchDialogViewCallbacks({
    required this.onAddStoryboard,
    required this.onBatchAddStoryboards,
    required this.onReloadBoards,
    required this.onOpenBatchWorkbench,
    required this.onReloadProductionSummary,
    required this.onOpenStoryboard,
    required this.onClose,
  });

  final VoidCallback? onAddStoryboard;
  final VoidCallback? onBatchAddStoryboards;
  final VoidCallback? onReloadBoards;
  final VoidCallback? onOpenBatchWorkbench;
  final VoidCallback? onReloadProductionSummary;
  final Future<void> Function(StoryboardRow board) onOpenStoryboard;
  final VoidCallback onClose;
}

class StoryboardsWorkbenchDialogView extends StatelessWidget {
  const StoryboardsWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final StoryboardsWorkbenchDialogViewModel model;
  final StoryboardsWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioAlertDialog(
      title: Text(l10n.scriptEditorStoryboardsDialogTitle(model.boardsList.length)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                model.boardsList.isEmpty
                    ? l10n.scriptEditorStoryboardsIntroEmpty
                    : l10n.scriptEditorStoryboardsIntroHasBoards,
                style: studioHintStyle(context),
              ),
              const SizedBox(height: 8),
              Text(
                model.productionSummaryLine ??
                    l10n.scriptEditorStoryboardsProductionSummaryPending,
                style: studioHintStyle(context),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
                decoration: studioRecessedPanelDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.diagnosis.summary,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.scriptEditorStoryboardsRecommendedActionLine(
                        describeStoryboardListRecommendedAction(
                          l10n,
                          model.diagnosis.recommendedAction,
                        ),
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(
                        color: studioPanelMutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.diagnosis.detail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (model.storyboardTaskLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  model.storyboardTaskLine!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: callbacks.onAddStoryboard,
                      child: Text(
                        model.actionBusy
                            ? l10n.scriptEditorStoryboardsBusy
                            : l10n.scriptEditorStoryboardAddDialogTitle,
                      ),
                    ),
                    TextButton(
                      onPressed: callbacks.onBatchAddStoryboards,
                      child: Text(l10n.scriptEditorStoryboardBatchAddDialogTitle),
                    ),
                    TextButton(
                      onPressed: callbacks.onReloadBoards,
                      child: Text(
                        model.boardsLoading
                            ? l10n.scriptEditorStoryboardsRefreshing
                            : l10n.scriptEditorStoryboardsRefreshList,
                      ),
                    ),
                    TextButton(
                      onPressed: callbacks.onOpenBatchWorkbench,
                      child: Text(l10n.scriptEditorStoryboardsOpenImageWorkbench),
                    ),
                    TextButton(
                      onPressed: callbacks.onReloadProductionSummary,
                      child: Text(
                        model.productionSummaryLoading
                            ? l10n.scriptEditorStoryboardsLoadingProductionView
                            : l10n.scriptEditorStoryboardsRefreshProductionView,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: model.boardsList.isEmpty
                    ? StudioEmptyState.emptyData(
                        title: l10n.scriptEditorStoryboardsEmptyList,
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: model.boardsList.length,
                        itemBuilder: (_, i) {
                          final board = model.boardsList[i];
                          final parts = <String>[
                            l10n.scriptEditorStoryboardsRowOrder(
                              board.sbIndex ?? i + 1,
                            ),
                            if ((board.state ?? '').trim().isNotEmpty)
                              l10n.scriptEditorStoryboardsRowState(
                                board.state!.trim(),
                              ),
                            if ((board.duration ?? '').trim().isNotEmpty)
                              l10n.scriptEditorStoryboardsRowDuration(
                                board.duration!.trim(),
                              ),
                          ];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.l10nBatch_46f00a087b(board.numericId)),
                            subtitle: Text(
                              [
                                if ((board.prompt ?? '').trim().isNotEmpty)
                                  board.prompt!.trim(),
                                if (parts.isNotEmpty) parts.join(' · '),
                              ].join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.edit_outlined, size: 18),
                            onTap: model.actionBusy || model.boardsLoading
                                ? null
                                : () => callbacks.onOpenStoryboard(board),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: callbacks.onClose,
          child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
        ),
      ],
    );
  }
}
