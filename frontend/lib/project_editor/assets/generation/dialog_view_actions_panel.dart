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
              child: Text(loadingSummary ? '同步中…' : '同步当前工作台摘要'),
            ),
            TextButton(
              onPressed: busyMutation ? null : onLoadMaterialContext,
              child: const Text('读取素材上下文'),
            ),
            TextButton(
              onPressed: busyMutation || visibleAssets.isEmpty
                  ? null
                  : onLoadBatchCandidates,
              child: const Text('读取批量候选'),
            ),
            TextButton(
              onPressed: busyMutation ? null : onSelectAllVisible,
              child: const Text('全选当前可见资产'),
            ),
            TextButton(
              onPressed: busyMutation || scopedAssets.isEmpty
                  ? null
                  : onRebuildSelectionByType,
              child: const Text('按类型重建选择'),
            ),
            TextButton(
              onPressed: busyMutation ? null : onClearSelection,
              child: const Text('清空选择'),
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
              child: Text(busyMutation ? '处理中…' : '批量发起资产出图'),
            ),
            TextButton(
              onPressed: busyMutation || selectedIds.isEmpty
                  ? null
                  : onPollImageStatuses,
              child: const Text('轮询图片状态'),
            ),
            TextButton(
              onPressed: busyMutation || selectedIds.isEmpty
                  ? null
                  : onPollPromptStatuses,
              child: const Text('轮询 prompt 状态'),
            ),
            TextButton(
              onPressed: busyMutation || selectedIds.isEmpty
                  ? null
                  : onDeleteDerivatives,
              child: const Text('清理衍生图'),
            ),
            TextButton(
              onPressed:
                  busyMutation ||
                      selectedSingleAssetId == null ||
                      imageUrlCtrl.text.trim().isEmpty
                  ? null
                  : onUpdateImageUrl,
              child: const Text('更新封面 URL'),
            ),
          ],
        ),
      ],
    );
  }
}

