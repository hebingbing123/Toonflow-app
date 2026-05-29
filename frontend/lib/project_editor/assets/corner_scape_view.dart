import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../design_system/components/studio_chip.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import '../../design_system/studio_responsive_layout.dart';
import '../../design_system/tokens.dart';
import '../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';
import 'package:openflow_app/design_system/ix/studio_form_keyboard.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    return StudioAlertDialog(
      title: Text(l10n.projectEditorAssetHistoryTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: StudioFormKeyboardScope(
            onEnterSubmit: model.busy || model.loading
                ? null
                : () {
                    final controller = studioFocusedTextField(
                      FocusManager.instance.primaryFocus?.context,
                    )?.controller;
                    if (controller == model.typesCtrl) {
                      callbacks.onRefresh();
                    }
                  },
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: model.typesCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorAssetHistoryTypeFilterLabel,
                  helperText: l10n.projectEditorAssetHistoryTypeFilterHelper,
                ),
                onSubmitted: model.loading
                    ? null
                    : (_) => callbacks.onRefresh(),
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDenseActionRow(
                spacing: StudioSpacing.xs,
                children: [
                  FilledButton(
                    style: studioFormPrimaryButtonStyle(context),
                    onPressed: model.busy || model.loading
                        ? null
                        : callbacks.onRefresh,
                    child: Text(model.loading ? l10n.projectEditorAssetHistoryLoading : l10n.projectEditorAssetHistoryQueryButton),
                  ),
                  TextButton(
                    onPressed: model.loading ? null : callbacks.onClearFilter,
                    child: Text(l10n.projectEditorAssetHistoryClearFilter),
                  ),
                  ...studioStaggeredChildren(
                    const ['role', 'clip', 'props', 'scene'].map(
                      (type) => StudioActionChip(
                        label: Text(type),
                        onPressed: model.loading
                            ? null
                            : () => callbacks.onPresetType(type),
                      ),
                    ),
                    entranceKey: 'corner_scape_preset_types',
                  ),
                ],
              ),
              if (model.summaryLine != null) ...[
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  model.summaryLine!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: StudioSpacing.sm),
              if (model.assets.isEmpty)
                model.loading
                    ? Text(
                        l10n.projectEditorAssetHistoryLoadingAssets,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: studioPanelMutedColor(context),
                        ),
                      )
                    : StudioEmptyState.emptyData(
                        title: l10n.projectEditorAssetHistoryEmptyState,
                        icon: Icons.photo_library_outlined,
                      )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final listHeight = studioAspectHeightFromWidth(
                      constraints.maxWidth.isFinite && constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : 360,
                      min: 140,
                      max: 240,
                    );
                    return SizedBox(
                  height: listHeight,
                  child: ListView.builder(
                    itemCount: model.assets.length,
                    itemBuilder: (context, index) {
                      final item = model.assets[index];
                      final selectedFlag =
                          item.numericId == model.selectedAssetNumericId;
                      return studioStaggeredItem(
                        index,
                        entranceKey: model.assets.length,
                        child: StudioListRow(
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
                        ),
                      );
                    },
                  ),
                    );
                  },
                ),
                const SizedBox(height: StudioSpacing.xs),
                if (model.selectedAsset != null &&
                    model.selectedAsset!.historyImages.isNotEmpty)
                  StudioDropdownButtonFormField<String>(
                    initialValue: model.selectedHistoryImageId,
                    decoration: InputDecoration(labelText: l10n.projectEditorAssetHistoryImageDropdownLabel),
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
                    l10n.projectEditorAssetHistoryNoImages,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(
                    color: studioPanelMutedColor(context),
                  ),
                  ),
                if (model.selectedImage != null) ...[
                  const SizedBox(height: StudioSpacing.xs),
                  Text(
                    l10n.projectEditorAssetHistoryCurrentImage(
                      model.selectedImage!.sortIndex,
                      model.selectedImage!.state ?? "-",
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: StudioSpacing.xs),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final previewHeight = studioPreviewImageHeight(
                      constraints.maxWidth.isFinite && constraints.maxWidth > 0
                          ? constraints.maxWidth
                          : 280,
                      fraction: 0.55,
                      min: 120,
                      max: 220,
                    );
                    if (model.loadingPreview) {
                      return SizedBox(
                        height: previewHeight,
                        child: const StudioMediaTileSkeleton(),
                      );
                    }
                    if (model.selectedPreviewBytes == null) {
                      return Text(
                        l10n.projectEditorAssetHistoryNoPreview,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: studioPanelMutedColor(context),
                        ),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(
                        StudioSpacing.radiusDense,
                      ),
                      child: Image.memory(
                        model.selectedPreviewBytes!,
                        height: previewHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: callbacks.onClose, child: Text(l10n.projectEditorAssetHistoryClose)),
      ],
    );
  }
}
