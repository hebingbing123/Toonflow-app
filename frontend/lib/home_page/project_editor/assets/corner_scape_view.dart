part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsCornerScapeWorkbenchView
    on _HomePageState {
  AlertDialog _buildCornerScapeWorkbenchDialog({
    required BuildContext ctx,
    required TextEditingController typesCtrl,
    required List<bool> assetsBusy,
    required List<CornerScapeAssetItem> assets,
    required int? selectedAssetNumericId,
    required String? selectedHistoryImageId,
    required Uint8List? selectedPreviewBytes,
    required bool loading,
    required bool loadingPreview,
    required String? summaryLine,
    required CornerScapeAssetItem? selectedAsset,
    required CornerScapeHistoryImage? selectedImage,
    required StateSetter setState,
    required Future<void> Function(StateSetter setState) refreshAssets,
    required Future<void> Function(StateSetter setState) loadPreview,
    required void Function(StateSetter setState) syncSummaryLine,
    required void Function(int assetNumericId) onAssetSelected,
    required void Function(String historyImageId) onHistoryImageSelected,
  }) {
    return AlertDialog(
      title: const Text('资产历史图工作台'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: typesCtrl,
              decoration: const InputDecoration(
                labelText: '类型过滤（可选）',
                helperText: '逗号分隔，例如 role,clip,props；留空表示全部',
              ),
              onSubmitted: loading ? null : (_) => refreshAssets(setState),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: assetsBusy[0] || loading
                      ? null
                      : () => refreshAssets(setState),
                  child: Text(loading ? '加载中…' : '查询历史图资产'),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () async {
                          typesCtrl.clear();
                          await refreshAssets(setState);
                        },
                  child: const Text('清空类型过滤'),
                ),
                ...const ['role', 'clip', 'props', 'scene'].map(
                  (type) => ActionChip(
                    label: Text(type),
                    onPressed: loading
                        ? null
                        : () async {
                            typesCtrl.text = type;
                            await refreshAssets(setState);
                          },
                  ),
                ),
              ],
            ),
            if (summaryLine != null) ...[
              const SizedBox(height: 8),
              Text(summaryLine, style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            if (assets.isEmpty)
              Text(
                loading ? '正在加载历史图资产…' : '暂无数据，点击“查询历史图资产”开始。',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.outline,
                ),
              )
            else ...[
              SizedBox(
                height: 180,
                child: ListView.builder(
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final item = assets[index];
                    final selectedFlag =
                        item.numericId == selectedAssetNumericId;
                    return ListTile(
                      dense: true,
                      selected: selectedFlag,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '#${item.numericId} ${item.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.assetType} · history_images=${item.historyImages.length}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        onAssetSelected(item.numericId);
                        syncSummaryLine(setState);
                        await loadPreview(setState);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (selectedAsset != null &&
                  selectedAsset.historyImages.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedHistoryImageId,
                  decoration: const InputDecoration(labelText: '历史图片'),
                  items: selectedAsset.historyImages
                      .map(
                        (img) => DropdownMenuItem<String>(
                          value: img.id,
                          child: Text(
                            '#${img.sortIndex} · ${img.state ?? "-"} · ${img.id.substring(0, img.id.length >= 8 ? 8 : img.id.length)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    onHistoryImageSelected(value);
                    syncSummaryLine(setState);
                    await loadPreview(setState);
                  },
                )
              else if (selectedAsset != null)
                Text(
                  '该资产暂无历史图片',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.outline,
                  ),
                ),
              if (selectedImage != null) ...[
                const SizedBox(height: 8),
                Text(
                  '当前图片：sort=${selectedImage.sortIndex} · state=${selectedImage.state ?? "-"}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              if (loadingPreview)
                const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (selectedPreviewBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    selectedPreviewBytes,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                )
              else
                Text(
                  '当前图片没有可用预览（可能仅存路径占位或远程资源暂不可达）',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.outline,
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
