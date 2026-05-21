part of 'dialog_view.dart';

class _AssetGenerationStatusPanel extends StatelessWidget {
  const _AssetGenerationStatusPanel({
    required this.busy,
    required this.statusLine,
    required this.productionData,
    required this.pollingData,
    required this.materialData,
    required this.batchData,
    required this.promptPollingData,
    required this.pollingSelections,
    required this.promptSelections,
    required this.onApplyPollingSelection,
    required this.onApplyMaterialSelection,
    required this.onApplyBatchSelection,
    required this.onApplyPromptSelection,
  });

  final bool busy;
  final String? statusLine;
  final AssetsDataResponseV1? productionData;
  final AssetsPollingImageResponseV1? pollingData;
  final WorkbenchAssetMaterialDataResponse? materialData;
  final WorkbenchAssetBatchGenerationResponse? batchData;
  final List<WorkbenchAssetPollingPromptItem>? promptPollingData;
  final Map<String, List<int>> pollingSelections;
  final Map<String, List<int>> promptSelections;
  final void Function(String label, List<int> ids) onApplyPollingSelection;
  final VoidCallback onApplyMaterialSelection;
  final VoidCallback onApplyBatchSelection;
  final void Function(String label, List<int> ids) onApplyPromptSelection;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final muted = studioPanelMutedColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (statusLine != null) ...[
          const SizedBox(height: 8),
          Text(statusLine!, style: bodySmall),
        ],
        if (productionData != null) ...[
          const SizedBox(height: 4),
          Text(
            summarizeProductionAssetData(productionData!, l10n),
            style: bodySmall?.copyWith(color: muted),
          ),
        ],
        if (pollingData != null) ...[
          const SizedBox(height: 4),
          Text(
            summarizeAssetPollingStatuses(pollingData!.statuses, l10n),
            style: bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pollingSelections.entries
                .map(
                  (entry) => ActionChip(
                    label: Text(
                      l10n.projectEditorAssetSummaryTypeCount(
                        entry.key,
                        entry.value.length,
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () => onApplyPollingSelection(entry.key, entry.value),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (materialData != null) ...[
          const SizedBox(height: 4),
          Text(
            summarizeWorkbenchAssetMaterialData(materialData!, l10n),
            style: bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: Text(
                  l10n.projectEditorAssetGenUseMaterialContext(
                    materialData!.data.length,
                  ),
                ),
                onPressed: busy ? null : onApplyMaterialSelection,
              ),
            ],
          ),
        ],
        if (batchData != null) ...[
          const SizedBox(height: 4),
          Text(
            summarizeWorkbenchBatchGenerationData(batchData!, l10n),
            style: bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: Text(
                  l10n.projectEditorAssetGenUseBatchCandidates(
                    batchData!.data.length,
                  ),
                ),
                onPressed: busy ? null : onApplyBatchSelection,
              ),
            ],
          ),
        ],
        if (promptPollingData != null) ...[
          const SizedBox(height: 4),
          Text(
            summarizeWorkbenchPromptPolling(promptPollingData!, l10n),
            style: bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: promptSelections.entries
                .map(
                  (entry) => ActionChip(
                    label: Text(
                      l10n.projectEditorAssetSummaryStateCount(
                        entry.key,
                        entry.value.length,
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () => onApplyPromptSelection(entry.key, entry.value),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}
