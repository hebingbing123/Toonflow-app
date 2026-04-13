part of '../../../../home_page.dart';

Widget _buildAssetImagesWorkbenchAssetField({
  required List<AssetRow> assets,
  required int selectedAssetNumericId,
  required Future<void> Function(int? value) onAssetChanged,
}) {
  return DropdownButtonFormField<int>(
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
  );
}

Widget _buildAssetImagesWorkbenchDiagnosisCard({
  required BuildContext dialogCtx,
  required AssetImagesWorkbenchDiagnosis diagnosis,
  required bool loadingList,
  required bool loadingPreview,
  required bool busyMutation,
  required Future<void> Function() onRecommendedAction,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(dialogCtx).colorScheme.outlineVariant),
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
        Text(diagnosis.detail, style: Theme.of(dialogCtx).textTheme.bodySmall),
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
  );
}

Widget _buildAssetImagesWorkbenchToolbar({
  required bool loadingList,
  required bool loadingPreview,
  required bool busyMutation,
  required Future<void> Function() onReloadImages,
  required Future<void> Function() onLoadPreview,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton(
        onPressed: loadingList || busyMutation ? null : onReloadImages,
        child: Text(loadingList ? '加载中…' : '加载图片列表'),
      ),
      TextButton(
        onPressed: loadingPreview || busyMutation ? null : onLoadPreview,
        child: Text(loadingPreview ? '预览中…' : '预览当前图片'),
      ),
    ],
  );
}

Widget _buildAssetImagesWorkbenchImageField({
  required List<AssetImageRow> imageItems,
  required String? selectedImageId,
  required Future<void> Function(String? value)? onImageChanged,
}) {
  return DropdownButtonFormField<String>(
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
  );
}

Widget _buildAssetImagesWorkbenchCreateForm({
  required TextEditingController createFilePathCtrl,
  required TextEditingController createStateCtrl,
  required TextEditingController createSortCtrl,
  required bool busyMutation,
  required Future<void> Function() onCreateImage,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: createFilePathCtrl,
        decoration: const InputDecoration(labelText: '新增 file_path（可选）'),
      ),
      const SizedBox(height: 8),
      _buildAssetImagesWorkbenchStateSortRow(
        stateCtrl: createStateCtrl,
        sortCtrl: createSortCtrl,
        stateLabel: '新增 state（可选）',
        sortLabel: '新增 sort_index（可选）',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: busyMutation ? null : onCreateImage,
          child: const Text('新增图片'),
        ),
      ),
    ],
  );
}

Widget _buildAssetImagesWorkbenchPatchForm({
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
  required bool busyMutation,
  required Future<void> Function() onPatchImage,
  required Future<void> Function() onDeleteImage,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: patchFilePathCtrl,
        decoration: const InputDecoration(labelText: '编辑 file_path（可置空）'),
      ),
      const SizedBox(height: 8),
      _buildAssetImagesWorkbenchStateSortRow(
        stateCtrl: patchStateCtrl,
        sortCtrl: patchSortCtrl,
        stateLabel: '编辑 state（可置空）',
        sortLabel: '编辑 sort_index（可选）',
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
    ],
  );
}

Widget _buildAssetImagesWorkbenchStateSortRow({
  required TextEditingController stateCtrl,
  required TextEditingController sortCtrl,
  required String stateLabel,
  required String sortLabel,
}) {
  return Row(
    children: [
      Expanded(
        child: TextField(
          controller: stateCtrl,
          decoration: InputDecoration(labelText: stateLabel),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: sortCtrl,
          decoration: InputDecoration(labelText: sortLabel),
          keyboardType: TextInputType.number,
        ),
      ),
    ],
  );
}

Widget _buildAssetImagesWorkbenchPreview(Uint8List? previewBytes) {
  if (previewBytes == null) {
    return const SizedBox.shrink();
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.memory(
      previewBytes,
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    ),
  );
}
