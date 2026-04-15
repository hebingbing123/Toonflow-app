import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import 'support.dart';

class AssetGenerationWorkbenchDialogViewModel {
  const AssetGenerationWorkbenchDialogViewModel({
    required this.scriptList,
    required this.visibleAssets,
    required this.scopedAssets,
    required this.typeSelections,
    required this.pollingSelections,
    required this.promptSelections,
    required this.selectedIds,
    required this.selectedSingleAssetId,
    required this.filterScriptNumericId,
    required this.selectedScriptNumericId,
    required this.selectedType,
    required this.loadingSummary,
    required this.busyMutation,
    required this.productionData,
    required this.pollingData,
    required this.materialData,
    required this.batchData,
    required this.promptPollingData,
    required this.statusLine,
    required this.modelCtrl,
    required this.resolutionCtrl,
    required this.imageUrlCtrl,
    required this.batchNameCtrl,
    required this.batchLimitCtrl,
  });

  final List<ScriptBrief> scriptList;
  final List<AssetRow> visibleAssets;
  final List<AssetRow> scopedAssets;
  final Map<String, List<int>> typeSelections;
  final Map<String, List<int>> pollingSelections;
  final Map<String, List<int>> promptSelections;
  final List<int> selectedIds;
  final int? selectedSingleAssetId;
  final int? filterScriptNumericId;
  final int selectedScriptNumericId;
  final String selectedType;
  final bool loadingSummary;
  final bool busyMutation;
  final AssetsDataResponseV1? productionData;
  final AssetsPollingImageResponseV1? pollingData;
  final WorkbenchAssetMaterialDataResponse? materialData;
  final WorkbenchAssetBatchGenerationResponse? batchData;
  final List<WorkbenchAssetPollingPromptItem>? promptPollingData;
  final String? statusLine;
  final TextEditingController modelCtrl;
  final TextEditingController resolutionCtrl;
  final TextEditingController imageUrlCtrl;
  final TextEditingController batchNameCtrl;
  final TextEditingController batchLimitCtrl;
}

class AssetGenerationWorkbenchDialogViewCallbacks {
  const AssetGenerationWorkbenchDialogViewCallbacks({
    required this.onScriptChanged,
    required this.onImageUrlChanged,
    required this.onTypeChanged,
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
    required this.onApplyPollingSelection,
    required this.onApplyMaterialSelection,
    required this.onApplyBatchSelection,
    required this.onApplyPromptSelection,
    required this.onToggleAsset,
    required this.onClose,
  });

  final ValueChanged<int> onScriptChanged;
  final ValueChanged<String> onImageUrlChanged;
  final ValueChanged<String> onTypeChanged;
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
  final void Function(String label, List<int> ids) onApplyPollingSelection;
  final VoidCallback onApplyMaterialSelection;
  final VoidCallback onApplyBatchSelection;
  final void Function(String label, List<int> ids) onApplyPromptSelection;
  final void Function(AssetRow asset, bool checked) onToggleAsset;
  final VoidCallback onClose;
}

class AssetGenerationWorkbenchDialogView extends StatelessWidget {
  const AssetGenerationWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final AssetGenerationWorkbenchDialogViewModel model;
  final AssetGenerationWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('资产出图工作台'),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把 production 资产摘要、批量出图、状态轮询、衍生图清理和封面 URL 更新收口到项目资产主流程，不再只依赖 system probe。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              _AssetGenerationControlsPanel(
                busy: model.busyMutation,
                scriptList: model.scriptList,
                typeSelections: model.typeSelections,
                selectedScriptNumericId: model.selectedScriptNumericId,
                selectedType: model.selectedType,
                modelCtrl: model.modelCtrl,
                resolutionCtrl: model.resolutionCtrl,
                imageUrlCtrl: model.imageUrlCtrl,
                batchNameCtrl: model.batchNameCtrl,
                batchLimitCtrl: model.batchLimitCtrl,
                onScriptChanged: callbacks.onScriptChanged,
                onImageUrlChanged: callbacks.onImageUrlChanged,
                onTypeChanged: callbacks.onTypeChanged,
              ),
              const SizedBox(height: 12),
              _AssetGenerationActionsPanel(
                loadingSummary: model.loadingSummary,
                busyMutation: model.busyMutation,
                visibleAssets: model.visibleAssets,
                scopedAssets: model.scopedAssets,
                selectedIds: model.selectedIds,
                selectedSingleAssetId: model.selectedSingleAssetId,
                imageUrlCtrl: model.imageUrlCtrl,
                onSyncWorkbenchSnapshot: callbacks.onSyncWorkbenchSnapshot,
                onLoadMaterialContext: callbacks.onLoadMaterialContext,
                onLoadBatchCandidates: callbacks.onLoadBatchCandidates,
                onSelectAllVisible: callbacks.onSelectAllVisible,
                onRebuildSelectionByType: callbacks.onRebuildSelectionByType,
                onClearSelection: callbacks.onClearSelection,
                onBatchGenerateImages: callbacks.onBatchGenerateImages,
                onPollImageStatuses: callbacks.onPollImageStatuses,
                onPollPromptStatuses: callbacks.onPollPromptStatuses,
                onDeleteDerivatives: callbacks.onDeleteDerivatives,
                onUpdateImageUrl: callbacks.onUpdateImageUrl,
              ),
              const SizedBox(height: 8),
              _AssetGenerationStatusPanel(
                busy: model.busyMutation,
                statusLine: model.statusLine,
                productionData: model.productionData,
                pollingData: model.pollingData,
                materialData: model.materialData,
                batchData: model.batchData,
                promptPollingData: model.promptPollingData,
                pollingSelections: model.pollingSelections,
                promptSelections: model.promptSelections,
                onApplyPollingSelection: callbacks.onApplyPollingSelection,
                onApplyMaterialSelection: callbacks.onApplyMaterialSelection,
                onApplyBatchSelection: callbacks.onApplyBatchSelection,
                onApplyPromptSelection: callbacks.onApplyPromptSelection,
              ),
              _AssetGenerationSelectionPanel(
                busy: model.busyMutation,
                filterScriptNumericId: model.filterScriptNumericId,
                scopedAssets: model.scopedAssets,
                selectedIds: model.selectedIds.toSet(),
                onToggleAsset: callbacks.onToggleAsset,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.busyMutation ? null : callbacks.onClose,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _AssetGenerationControlsPanel extends StatelessWidget {
  const _AssetGenerationControlsPanel({
    required this.busy,
    required this.scriptList,
    required this.typeSelections,
    required this.selectedScriptNumericId,
    required this.selectedType,
    required this.modelCtrl,
    required this.resolutionCtrl,
    required this.imageUrlCtrl,
    required this.batchNameCtrl,
    required this.batchLimitCtrl,
    required this.onScriptChanged,
    required this.onTypeChanged,
    required this.onImageUrlChanged,
  });

  final bool busy;
  final List<ScriptBrief> scriptList;
  final Map<String, List<int>> typeSelections;
  final int selectedScriptNumericId;
  final String selectedType;
  final TextEditingController modelCtrl;
  final TextEditingController resolutionCtrl;
  final TextEditingController imageUrlCtrl;
  final TextEditingController batchNameCtrl;
  final TextEditingController batchLimitCtrl;
  final ValueChanged<int> onScriptChanged;
  final ValueChanged<String> onImageUrlChanged;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: selectedScriptNumericId,
                decoration: const InputDecoration(
                  labelText: '生成使用的剧本',
                  helperText: '批量出图会把所选资产投给这个剧本上下文',
                ),
                items: scriptList
                    .map(
                      (script) => DropdownMenuItem<int>(
                        value: script.numericId,
                        child: Text(
                          '#${script.numericId} ${script.name ?? ""}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        onScriptChanged(value);
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: '资产类型筛选',
                  helperText: '同时影响 production 摘要读取和可见选择集',
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('（全部类型）'),
                  ),
                  ...typeSelections.keys.map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  ),
                ],
                onChanged: busy ? null : (value) => onTypeChanged(value ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: '模型（可选）'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: resolutionCtrl,
                decoration: const InputDecoration(labelText: '分辨率（可选）'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: batchNameCtrl,
                decoration: const InputDecoration(labelText: '批量候选名称过滤（可选）'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextField(
                controller: batchLimitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '候选 limit'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: imageUrlCtrl,
          onChanged: onImageUrlChanged,
          decoration: const InputDecoration(
            labelText: '更新封面 URL（单选时可用）',
            helperText: '用于 production/assets/update-assets-url',
          ),
        ),
      ],
    );
  }
}

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

class _AssetGenerationSelectionPanel extends StatelessWidget {
  const _AssetGenerationSelectionPanel({
    required this.busy,
    required this.filterScriptNumericId,
    required this.scopedAssets,
    required this.selectedIds,
    required this.onToggleAsset,
  });

  final bool busy;
  final int? filterScriptNumericId;
  final List<AssetRow> scopedAssets;
  final Set<int> selectedIds;
  final void Function(AssetRow asset, bool checked) onToggleAsset;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filterScriptNumericId == null
              ? '当前按项目全量资产操作；可在主视图先切换"按剧本筛选"再进入工作台。'
              : '当前主视图已按剧本 #$filterScriptNumericId 过滤资产，工作台默认沿用这批可见资产。',
          style: bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.builder(
            itemCount: scopedAssets.length,
            itemBuilder: (context, index) {
              final asset = scopedAssets[index];
              return CheckboxListTile(
                dense: true,
                value: selectedIds.contains(asset.numericId),
                onChanged: busy
                    ? null
                    : (checked) => onToggleAsset(asset, checked == true),
                title: Text('#${asset.numericId} ${asset.name}'),
                subtitle: Text(
                  [
                    asset.assetType,
                    asset.description?.trim().isNotEmpty == true
                        ? asset.description!.trim()
                        : '无描述',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }
}
