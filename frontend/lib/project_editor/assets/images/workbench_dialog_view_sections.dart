import 'package:flutter/material.dart';

import '../support.dart';
import 'workbench_dialog_view.dart';

List<Widget> buildAssetImagesWorkbenchSections(
  BuildContext context, {
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  final sections = <Widget>[
    _buildAssetField(model: model, callbacks: callbacks),
    _buildDiagnosisCard(context, model: model, callbacks: callbacks),
    _buildToolbar(model: model, callbacks: callbacks),
    if (model.statusLine != null)
      Text(model.statusLine!, style: Theme.of(context).textTheme.bodySmall),
    _buildImageField(model: model, callbacks: callbacks),
    _buildMutationForm(
      filePathController: model.createFilePathController,
      stateController: model.createStateController,
      sortController: model.createSortController,
      filePathLabel: '新增 file_path（可选）',
      stateLabel: '新增 state（可选）',
      sortLabel: '新增 sort_index（可选）',
      actions: [
        AssetImagesWorkbenchMutationAction(
          label: '新增图片',
          onPressed: callbacks.onCreateImage,
        ),
      ],
    ),
    _buildMutationForm(
      filePathController: model.patchFilePathController,
      stateController: model.patchStateController,
      sortController: model.patchSortController,
      filePathLabel: '编辑 file_path（可置空）',
      stateLabel: '编辑 state（可置空）',
      sortLabel: '编辑 sort_index（可选）',
      actions: [
        AssetImagesWorkbenchMutationAction(
          label: '保存当前图片',
          onPressed: callbacks.onPatchImage,
        ),
        AssetImagesWorkbenchMutationAction(
          label: '删除当前图片',
          onPressed: callbacks.onDeleteImage,
        ),
      ],
    ),
    if (model.previewBytes != null)
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          model.previewBytes!,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
  ];
  return _interleaveVisibleSections(sections);
}

Widget _buildAssetField({
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  return DropdownButtonFormField<int>(
    initialValue: model.selectedAssetNumericId,
    decoration: const InputDecoration(labelText: '目标资产'),
    items: model.assets
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

Widget _buildDiagnosisCard(
  BuildContext context, {
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          model.diagnosis.summary,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          model.diagnosis.detail,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          key: const Key('asset-images-workbench-recommended-action'),
          onPressed: callbacks.onRecommendedAction,
          child: Text(
            describeAssetImagesWorkbenchRecommendedAction(
              model.diagnosis.recommendedAction,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildToolbar({
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton(
        onPressed: callbacks.onReloadImages,
        child: Text(model.loadingList ? '加载中…' : '加载图片列表'),
      ),
      TextButton(
        onPressed: callbacks.onLoadPreview,
        child: Text(model.loadingPreview ? '预览中…' : '预览当前图片'),
      ),
    ],
  );
}

Widget _buildImageField({
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  return DropdownButtonFormField<String>(
    initialValue: model.selectedImageId,
    decoration: const InputDecoration(labelText: '图片列表'),
    items: model.imageItems
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

Widget _buildMutationForm({
  required TextEditingController filePathController,
  required TextEditingController stateController,
  required TextEditingController sortController,
  required String filePathLabel,
  required String stateLabel,
  required String sortLabel,
  required List<AssetImagesWorkbenchMutationAction> actions,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: filePathController,
        decoration: InputDecoration(labelText: filePathLabel),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: stateController,
              decoration: InputDecoration(labelText: stateLabel),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: sortController,
              decoration: InputDecoration(labelText: sortLabel),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions
              .map(
                (action) => TextButton(
                  onPressed: action.onPressed,
                  child: Text(action.label),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}

List<Widget> _interleaveVisibleSections(List<Widget> sections) {
  if (sections.isEmpty) {
    return const <Widget>[];
  }
  final spacedSections = <Widget>[sections.first];
  for (final section in sections.skip(1)) {
    spacedSections
      ..add(const SizedBox(height: assetImagesWorkbenchSectionSpacing))
      ..add(section);
  }
  return spacedSections;
}

class AssetImagesWorkbenchMutationAction {
  const AssetImagesWorkbenchMutationAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;
}

