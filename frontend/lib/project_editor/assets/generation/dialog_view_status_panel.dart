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
    final outline = Theme.of(context).colorScheme.outline;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
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
            summarizeProductionAssetData(productionData!),
            style: bodySmall?.copyWith(color: outline),
          ),
        ],
        if (pollingData != null) ...[
          const SizedBox(height: 4),
          Text(
            summarizeAssetPollingStatuses(pollingData!.statuses),
            style: bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pollingSelections.entries
                .map(
                  (entry) => ActionChip(
                    label: Text('${entry.key} ${entry.value.length} 条'),
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
            summarizeWorkbenchAssetMaterialData(materialData!),
            style: bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: Text('使用素材上下文 ${materialData!.data.length} 条'),
                onPressed: busy ? null : onApplyMaterialSelection,
              ),
            ],
          ),
        ],
        if (batchData != null) ...[
          const SizedBox(height: 4),
          Text(
            summarizeWorkbenchBatchGenerationData(batchData!),
            style: bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: Text('使用批量候选 ${batchData!.data.length} 条'),
                onPressed: busy ? null : onApplyBatchSelection,
              ),
            ],
          ),
        ],
        if (promptPollingData != null) ...[
          const SizedBox(height: 4),
          Text(
            summarizeWorkbenchPromptPolling(promptPollingData!),
            style: bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: promptSelections.entries
                .map(
                  (entry) => ActionChip(
                    label: Text('${entry.key} ${entry.value.length} 条'),
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

