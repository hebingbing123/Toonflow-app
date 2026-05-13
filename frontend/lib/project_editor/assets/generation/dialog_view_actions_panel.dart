part of 'dialog_view.dart';

class _AssetGenerationActionsPanel extends StatelessWidget {
  const _AssetGenerationActionsPanel({
    required this.loadingSummary,
    required this.busyMutation,
    required this.visibleAssets,
    required this.scopedAssets,
    required this.selectedIds,
    required this.selectedSingleAssetId,
    required this.imageUrlCtrl,
    required this.onSyncWorkbenchSnapshot,
    required this.onLoadMaterialContext,
    required this.onLoadBatchCandidates,
    required this.onSelectAllVisible,
    required this.onRebuildSelectionByType,
    required this.onClearSelection,
    required this.onBatchGenerateImages,
    required this.onPollImageStatuses,
    required this.onPollPromptStatuses,
    required this.onDeleteDerivatives,
    required this.onUpdateImageUrl,
  });

  final bool loadingSummary;
  final bool busyMutation;
  final List<AssetRow> visibleAssets;
  final List<AssetRow> scopedAssets;
  final List<int> selectedIds;
  final int? selectedSingleAssetId;
  final TextEditingController imageUrlCtrl;
  final VoidCallback onSyncWorkbenchSnapshot;
  final VoidCallback onLoadMaterialContext;
  final VoidCallback onLoadBatchCandidates;
  final VoidCallback onSelectAllVisible;
  final VoidCallback onRebuildSelectionByType;
  final VoidCallback onClearSelection;
  final VoidCallback onBatchGenerateImages;
  final VoidCallback onPollImageStatuses;
  final VoidCallback onPollPromptStatuses;
  final VoidCallback onDeleteDerivatives;
  final VoidCallback onUpdateImageUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingSummary || busyMutation
                  ? null
                  : onSyncWorkbenchSnapshot,
              child: Text(
                loadingSummary
                    ? l10n.projectEditorAssetGenWorkbenchSyncSummaryBusy
                    : l10n.projectEditorAssetGenWorkbenchSyncSummary,
              ),
            ),
            TextButton(
              onPressed: busyMutation ? null : onLoadMaterialContext,
              child: Text(l10n.projectEditorAssetGenWorkbenchLoadMaterialContext),
            ),
            TextButton(
              onPressed: busyMutation || visibleAssets.isEmpty
                  ? null
                  : onLoadBatchCandidates,
              child: Text(l10n.projectEditorAssetGenWorkbenchLoadBatchCandidates),
            ),
            TextButton(
              onPressed: busyMutation ? null : onSelectAllVisible,
              child: Text(l10n.projectEditorAssetGenWorkbenchSelectAllVisible),
            ),
            TextButton(
              onPressed: busyMutation || scopedAssets.isEmpty
                  ? null
                  : onRebuildSelectionByType,
              child: Text(l10n.projectEditorAssetGenWorkbenchRebuildSelectionByType),
            ),
            TextButton(
              onPressed: busyMutation ? null : onClearSelection,
              child: Text(l10n.projectEditorAssetGenWorkbenchClearSelection),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: busyMutation || selectedIds.isEmpty
                  ? null
                  : onBatchGenerateImages,
              child: Text(
                busyMutation
                    ? l10n.projectEditorAssetGenWorkbenchMutationBusy
                    : l10n.projectEditorAssetGenWorkbenchBatchGenerate,
              ),
            ),
            TextButton(
              onPressed: busyMutation || selectedIds.isEmpty
                  ? null
                  : onPollImageStatuses,
              child: Text(l10n.projectEditorAssetGenWorkbenchPollImageStatuses),
            ),
            TextButton(
              onPressed: busyMutation || selectedIds.isEmpty
                  ? null
                  : onPollPromptStatuses,
              child: Text(l10n.projectEditorAssetGenWorkbenchPollPromptStatuses),
            ),
            TextButton(
              onPressed: busyMutation || selectedIds.isEmpty
                  ? null
                  : onDeleteDerivatives,
              child: Text(l10n.projectEditorAssetGenWorkbenchDeleteDerivatives),
            ),
            TextButton(
              onPressed:
                  busyMutation ||
                      selectedSingleAssetId == null ||
                      imageUrlCtrl.text.trim().isEmpty
                  ? null
                  : onUpdateImageUrl,
              child: Text(l10n.projectEditorAssetGenWorkbenchUpdateCoverUrl),
            ),
          ],
        ),
      ],
    );
  }
}

