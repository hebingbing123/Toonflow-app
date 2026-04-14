import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import '../support.dart';

const double assetImagesWorkbenchSectionSpacing = 8;

class AssetImagesWorkbenchDialogViewModel {
  const AssetImagesWorkbenchDialogViewModel({
    required this.assets,
    required this.imageItems,
    required this.selectedAssetNumericId,
    required this.selectedImageId,
    required this.diagnosis,
    required this.loadingList,
    required this.loadingPreview,
    required this.busyMutation,
    required this.statusLine,
    required this.previewBytes,
    required this.createFilePathController,
    required this.createStateController,
    required this.createSortController,
    required this.patchFilePathController,
    required this.patchStateController,
    required this.patchSortController,
  });

  final List<AssetRow> assets;
  final List<AssetImageRow> imageItems;
  final int selectedAssetNumericId;
  final String? selectedImageId;
  final AssetImagesWorkbenchDiagnosis diagnosis;
  final bool loadingList;
  final bool loadingPreview;
  final bool busyMutation;
  final String? statusLine;
  final Uint8List? previewBytes;
  final TextEditingController createFilePathController;
  final TextEditingController createStateController;
  final TextEditingController createSortController;
  final TextEditingController patchFilePathController;
  final TextEditingController patchStateController;
  final TextEditingController patchSortController;
}

class AssetImagesWorkbenchDialogViewCallbacks {
  const AssetImagesWorkbenchDialogViewCallbacks({
    required this.onAssetChanged,
    required this.onRecommendedAction,
    required this.onReloadImages,
    required this.onLoadPreview,
    required this.onImageChanged,
    required this.onCreateImage,
    required this.onPatchImage,
    required this.onDeleteImage,
  });

  final ValueChanged<int?> onAssetChanged;
  final VoidCallback? onRecommendedAction;
  final VoidCallback? onReloadImages;
  final VoidCallback? onLoadPreview;
  final ValueChanged<String?> onImageChanged;
  final VoidCallback? onCreateImage;
  final VoidCallback? onPatchImage;
  final VoidCallback? onDeleteImage;
}

class AssetImagesWorkbenchDialogView extends StatelessWidget {
  const AssetImagesWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final AssetImagesWorkbenchDialogViewModel model;
  final AssetImagesWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('资产图片工作台'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildAssetImagesWorkbenchSections(context),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  List<Widget> _buildAssetImagesWorkbenchSections(BuildContext context) {
    final sections = <Widget>[
      _buildAssetField(),
      _buildDiagnosisCard(context),
      _buildToolbar(),
      if (model.statusLine != null)
        Text(model.statusLine!, style: Theme.of(context).textTheme.bodySmall),
      _buildImageField(),
      _buildMutationForm(
        filePathController: model.createFilePathController,
        stateController: model.createStateController,
        sortController: model.createSortController,
        filePathLabel: '新增 file_path（可选）',
        stateLabel: '新增 state（可选）',
        sortLabel: '新增 sort_index（可选）',
        actions: [
          _AssetImagesWorkbenchMutationAction(
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
          _AssetImagesWorkbenchMutationAction(
            label: '保存当前图片',
            onPressed: callbacks.onPatchImage,
          ),
          _AssetImagesWorkbenchMutationAction(
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

  Widget _buildAssetField() {
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

  Widget _buildDiagnosisCard(BuildContext context) {
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

  Widget _buildToolbar() {
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

  Widget _buildImageField() {
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
    required List<_AssetImagesWorkbenchMutationAction> actions,
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
}

class _AssetImagesWorkbenchMutationAction {
  const _AssetImagesWorkbenchMutationAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;
}
