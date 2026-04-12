part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesWorkbenchDialog on _HomePageState {
  /// 资产图片工作台的对话框主体，和请求流程分开，降低入口函数复杂度。
  AlertDialog _buildAssetImagesWorkbenchDialog({
    required BuildContext ctx,
    required BuildContext dialogCtx,
    required List<AssetRow> assets,
    required List<AssetImageRow> imageItems,
    required int selectedAssetNumericId,
    required String? selectedImageId,
    required AssetImagesWorkbenchDiagnosis diagnosis,
    required bool loadingList,
    required bool loadingPreview,
    required bool busyMutation,
    required String? statusLine,
    required Uint8List? previewBytes,
    required TextEditingController createFilePathCtrl,
    required TextEditingController createStateCtrl,
    required TextEditingController createSortCtrl,
    required TextEditingController patchFilePathCtrl,
    required TextEditingController patchStateCtrl,
    required TextEditingController patchSortCtrl,
    required Future<void> Function(int? value) onAssetChanged,
    required Future<void> Function() onRecommendedAction,
    required Future<void> Function() onReloadImages,
    required Future<void> Function() onLoadPreview,
    required Future<void> Function(String? value)? onImageChanged,
    required Future<void> Function() onCreateImage,
    required Future<void> Function() onPatchImage,
    required Future<void> Function() onDeleteImage,
  }) {
    return AlertDialog(
      title: const Text('资产图片工作台'),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: selectedAssetNumericId,
              decoration: const InputDecoration(labelText: '目标资产'),
              items: assets
                  .map(
                    (asset) => DropdownMenuItem<int>(
                      value: asset.numericId,
                      child: Text(
                        '#${asset.numericId} ${asset.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onAssetChanged,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(dialogCtx).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diagnosis.summary,
                    style: Theme.of(dialogCtx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    diagnosis.detail,
                    style: Theme.of(dialogCtx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: loadingList || loadingPreview || busyMutation
                        ? null
                        : onRecommendedAction,
                    child: Text(
                      describeAssetImagesWorkbenchRecommendedAction(
                        diagnosis.recommendedAction,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: loadingList || busyMutation
                      ? null
                      : onReloadImages,
                  child: Text(loadingList ? '加载中…' : '加载图片列表'),
                ),
                TextButton(
                  onPressed: loadingPreview || busyMutation
                      ? null
                      : onLoadPreview,
                  child: Text(loadingPreview ? '预览中…' : '预览当前图片'),
                ),
              ],
            ),
            if (statusLine != null) ...[
              const SizedBox(height: 8),
              Text(statusLine, style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedImageId,
              decoration: const InputDecoration(labelText: '图片列表'),
              items: imageItems
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
              onChanged: onImageChanged,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: createFilePathCtrl,
              decoration: const InputDecoration(labelText: '新增 file_path（可选）'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: createStateCtrl,
                    decoration: const InputDecoration(
                      labelText: '新增 state（可选）',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: createSortCtrl,
                    decoration: const InputDecoration(
                      labelText: '新增 sort_index（可选）',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busyMutation ? null : onCreateImage,
                child: const Text('新增图片'),
              ),
            ),
            TextField(
              controller: patchFilePathCtrl,
              decoration: const InputDecoration(labelText: '编辑 file_path（可置空）'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: patchStateCtrl,
                    decoration: const InputDecoration(
                      labelText: '编辑 state（可置空）',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: patchSortCtrl,
                    decoration: const InputDecoration(
                      labelText: '编辑 sort_index（可选）',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: busyMutation ? null : onPatchImage,
                  child: const Text('保存当前图片'),
                ),
                TextButton(
                  onPressed: busyMutation ? null : onDeleteImage,
                  child: const Text('删除当前图片'),
                ),
              ],
            ),
            if (previewBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  previewBytes,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
