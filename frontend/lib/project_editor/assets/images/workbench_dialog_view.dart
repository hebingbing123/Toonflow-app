import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import '../support.dart';
import 'workbench_dialog_view_sections.dart';

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
            children: buildAssetImagesWorkbenchSections(
              context,
              model: model,
              callbacks: callbacks,
            ),
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

}
