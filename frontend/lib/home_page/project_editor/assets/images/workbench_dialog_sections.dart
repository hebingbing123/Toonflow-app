part of '../../../../home_page.dart';

Widget _buildAssetImagesWorkbenchAssetField({
  required AssetImagesWorkbenchDialogState state,
  required AssetImagesWorkbenchDialogCallbacks callbacks,
}) {
  return DropdownButtonFormField<int>(
    initialValue: state.selectedAssetNumericId,
    decoration: const InputDecoration(labelText: '目标资产'),
    items: state.assets
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
    onChanged: callbacks.onAssetChanged,
  );
}

Widget _buildAssetImagesWorkbenchDiagnosisCard({
  required BuildContext dialogCtx,
  required AssetImagesWorkbenchDialogState state,
  required AssetImagesWorkbenchDialogCallbacks callbacks,
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
          state.diagnosis.summary,
          style: Theme.of(dialogCtx).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          state.diagnosis.detail,
          style: Theme.of(dialogCtx).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              state.loadingList || state.loadingPreview || state.busyMutation
              ? null
              : callbacks.onRecommendedAction,
          child: Text(
            describeAssetImagesWorkbenchRecommendedAction(
              state.diagnosis.recommendedAction,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildAssetImagesWorkbenchToolbar({
  required AssetImagesWorkbenchDialogState state,
  required AssetImagesWorkbenchDialogCallbacks callbacks,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton(
        onPressed: state.loadingList || state.busyMutation
            ? null
            : callbacks.onReloadImages,
        child: Text(state.loadingList ? '加载中…' : '加载图片列表'),
      ),
      TextButton(
        onPressed: state.loadingPreview || state.busyMutation
            ? null
            : callbacks.onLoadPreview,
        child: Text(state.loadingPreview ? '预览中…' : '预览当前图片'),
      ),
    ],
  );
}

Widget _buildAssetImagesWorkbenchImageField({
  required AssetImagesWorkbenchDialogState state,
  required AssetImagesWorkbenchDialogCallbacks callbacks,
}) {
  return DropdownButtonFormField<String>(
    initialValue: state.selectedImageId,
    decoration: const InputDecoration(labelText: '图片列表'),
    items: state.imageItems
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
    onChanged: callbacks.onImageChanged,
  );
}

Widget _buildAssetImagesWorkbenchCreateForm({
  required AssetImagesWorkbenchDialogState state,
  required AssetImagesWorkbenchDialogCallbacks callbacks,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: state.createControllers.filePathCtrl,
        decoration: const InputDecoration(labelText: '新增 file_path（可选）'),
      ),
      const SizedBox(height: 8),
      _buildAssetImagesWorkbenchStateSortRow(
        stateCtrl: state.createControllers.stateCtrl,
        sortCtrl: state.createControllers.sortCtrl,
        stateLabel: '新增 state（可选）',
        sortLabel: '新增 sort_index（可选）',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: state.busyMutation ? null : callbacks.onCreateImage,
          child: const Text('新增图片'),
        ),
      ),
    ],
  );
}

Widget _buildAssetImagesWorkbenchPatchForm({
  required AssetImagesWorkbenchDialogState state,
  required AssetImagesWorkbenchDialogCallbacks callbacks,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: state.patchControllers.filePathCtrl,
        decoration: const InputDecoration(labelText: '编辑 file_path（可置空）'),
      ),
      const SizedBox(height: 8),
      _buildAssetImagesWorkbenchStateSortRow(
        stateCtrl: state.patchControllers.stateCtrl,
        sortCtrl: state.patchControllers.sortCtrl,
        stateLabel: '编辑 state（可置空）',
        sortLabel: '编辑 sort_index（可选）',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: state.busyMutation ? null : callbacks.onPatchImage,
            child: const Text('保存当前图片'),
          ),
          TextButton(
            onPressed: state.busyMutation ? null : callbacks.onDeleteImage,
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

Widget _buildAssetImagesWorkbenchPreview({
  required AssetImagesWorkbenchDialogState state,
}) {
  if (state.previewBytes == null) {
    return const SizedBox.shrink();
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.memory(
      state.previewBytes!,
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    ),
  );
}
