import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../rust_api.dart';
import '../support.dart';
import 'workbench_dialog_view.dart';

List<Widget> buildAssetImagesWorkbenchSections(
  BuildContext context, {
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  final l10n = resolveAppLocalizationsForErrors(context);
  final sections = <Widget>[
    _buildAssetField(l10n: l10n, model: model, callbacks: callbacks),
    _buildDiagnosisCard(context, l10n: l10n, model: model, callbacks: callbacks),
    _buildToolbar(l10n: l10n, model: model, callbacks: callbacks),
    if (model.statusLine != null)
      Text(model.statusLine!, style: Theme.of(context).textTheme.bodySmall),
    _buildImageField(l10n: l10n, model: model, callbacks: callbacks),
    _buildMutationForm(
      filePathController: model.createFilePathController,
      stateController: model.createStateController,
      sortController: model.createSortController,
      filePathLabel: l10n.projectEditorAssetImagesNewFilePathOptional,
      stateLabel: l10n.projectEditorAssetImagesNewStateOptional,
      sortLabel: l10n.projectEditorAssetImagesNewSortOptional,
      actions: [
        AssetImagesWorkbenchMutationAction(
          label: l10n.projectEditorAssetImagesAddImage,
          onPressed: callbacks.onCreateImage,
        ),
      ],
    ),
    _buildMutationForm(
      filePathController: model.patchFilePathController,
      stateController: model.patchStateController,
      sortController: model.patchSortController,
      filePathLabel: l10n.projectEditorAssetImagesEditFilePathMayClear,
      stateLabel: l10n.projectEditorAssetImagesEditStateMayClear,
      sortLabel: l10n.projectEditorAssetImagesEditSortOptional,
      actions: [
        AssetImagesWorkbenchMutationAction(
          label: l10n.projectEditorAssetImagesSaveCurrentImage,
          onPressed: callbacks.onPatchImage,
        ),
        AssetImagesWorkbenchMutationAction(
          label: l10n.projectEditorAssetImagesDeleteCurrentImage,
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
  required AppLocalizations l10n,
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  return StudioDropdownButtonFormField<int>(
    initialValue: model.selectedAssetNumericId,
    decoration: InputDecoration(labelText: l10n.projectEditorAssetImagesFieldTargetAsset),
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
  required AppLocalizations l10n,
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
    decoration: studioInsetPanelDecoration(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          model.diagnosis.summary,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
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
              l10n,
              model.diagnosis.recommendedAction,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildToolbar({
  required AppLocalizations l10n,
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton(
        onPressed: callbacks.onReloadImages,
        child: Text(
          model.loadingList
              ? l10n.projectEditorAssetImagesLoadingEllipsis
              : l10n.projectEditorAssetImagesLoadImageList,
        ),
      ),
      TextButton(
        onPressed: callbacks.onLoadPreview,
        child: Text(
          model.loadingPreview
              ? l10n.projectEditorAssetImagesLoadingPreview
              : l10n.projectEditorAssetImagesPreviewImage,
        ),
      ),
    ],
  );
}

Widget _buildImageField({
  required AppLocalizations l10n,
  required AssetImagesWorkbenchDialogViewModel model,
  required AssetImagesWorkbenchDialogViewCallbacks callbacks,
}) {
  return StudioDropdownButtonFormField<String>(
    initialValue: model.selectedImageId,
    decoration: InputDecoration(labelText: l10n.projectEditorAssetImagesFieldImages),
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
