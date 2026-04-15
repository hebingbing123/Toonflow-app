import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../rust_api.dart';

class CornerScapeWorkbenchDialogViewModel {
  const CornerScapeWorkbenchDialogViewModel({
    required this.typesCtrl,
    required this.busy,
    required this.assets,
    required this.selectedAssetNumericId,
    required this.selectedHistoryImageId,
    required this.selectedPreviewBytes,
    required this.loading,
    required this.loadingPreview,
    required this.summaryLine,
    required this.selectedAsset,
    required this.selectedImage,
  });

  final TextEditingController typesCtrl;
  final bool busy;
  final List<CornerScapeAssetItem> assets;
  final int? selectedAssetNumericId;
  final String? selectedHistoryImageId;
  final Uint8List? selectedPreviewBytes;
  final bool loading;
  final bool loadingPreview;
  final String? summaryLine;
  final CornerScapeAssetItem? selectedAsset;
  final CornerScapeHistoryImage? selectedImage;
}

class CornerScapeWorkbenchDialogViewCallbacks {
  const CornerScapeWorkbenchDialogViewCallbacks({
    required this.onRefresh,
    required this.onClearFilter,
    required this.onPresetType,
    required this.onAssetSelected,
    required this.onHistoryImageSelected,
    required this.onClose,
  });

  final Future<void> Function() onRefresh;
  final Future<void> Function() onClearFilter;
  final Future<void> Function(String type) onPresetType;
  final Future<void> Function(int assetNumericId) onAssetSelected;
  final Future<void> Function(String historyImageId) onHistoryImageSelected;
  final VoidCallback onClose;
}

class CornerScapeWorkbenchDialogView extends StatelessWidget {
  const CornerScapeWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final CornerScapeWorkbenchDialogViewModel model;
  final CornerScapeWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: const Text('资产历史图工作台'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: model.typesCtrl,
                decoration: const InputDecoration(
                  labelText: '类型过滤（可选）',
                  helperText: '逗号分隔，例如 role,clip,props；留空表示全部',
                ),
                onSubmitted: model.loading
                    ? null
                    : (_) => callbacks.onRefresh(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: model.busy || model.loading
                        ? null
                        : callbacks.onRefresh,
                    child: Text(model.loading ? '加载中…' : '查询历史图资产'),
                  ),
                  TextButton(
                    onPressed: model.loading ? null : callbacks.onClearFilter,
                    child: const Text('清空类型过滤'),
                  ),
                  ...const ['role', 'clip', 'props', 'scene'].map(
                    (type) => ActionChip(
                      label: Text(type),
                      onPressed: model.loading
                          ? null
                          : () => callbacks.onPresetType(type),
                    ),
                  ),
                ],
              ),
              if (model.summaryLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  model.summaryLine!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              if (model.assets.isEmpty)
                Text(
                  model.loading ? '正在加载历史图资产…' : '暂无数据，点击“查询历史图资产”开始。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                )
              else ...[
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    itemCount: model.assets.length,
                    itemBuilder: (context, index) {
                      final item = model.assets[index];
                      final selectedFlag =
                          item.numericId == model.selectedAssetNumericId;
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
                        onTap: () => callbacks.onAssetSelected(item.numericId),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (model.selectedAsset != null &&
                    model.selectedAsset!.historyImages.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: model.selectedHistoryImageId,
                    decoration: const InputDecoration(labelText: '历史图片'),
                    items: model.selectedAsset!.historyImages
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
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      callbacks.onHistoryImageSelected(value);
                    },
                  )
                else if (model.selectedAsset != null)
                  Text(
                    '该资产暂无历史图片',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: outline),
                  ),
                if (model.selectedImage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '当前图片：sort=${model.selectedImage!.sortIndex} · state=${model.selectedImage!.state ?? "-"}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                if (model.loadingPreview)
                  const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (model.selectedPreviewBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      model.selectedPreviewBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  )
                else
                  Text(
                    '当前图片没有可用预览（可能仅存路径占位或远程资源暂不可达）',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: outline),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: callbacks.onClose, child: const Text('关闭')),
      ],
    );
  }
}
