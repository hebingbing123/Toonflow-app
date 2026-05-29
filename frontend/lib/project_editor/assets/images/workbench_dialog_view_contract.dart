import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import '../support.dart';

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
    required this.assetBlocks,
    required this.loadingBlocks,
    required this.blockKeyController,
    required this.projectId,
    required this.accessToken,
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
  final List<AssetBlockRow> assetBlocks;
  final bool loadingBlocks;
  final TextEditingController blockKeyController;
  final String projectId;
  final String accessToken;
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
    required this.onReloadBlocks,
    required this.onRegisterBlock,
  });

  final ValueChanged<int?> onAssetChanged;
  final VoidCallback? onRecommendedAction;
  final VoidCallback? onReloadImages;
  final VoidCallback? onLoadPreview;
  final ValueChanged<String?> onImageChanged;
  final VoidCallback? onCreateImage;
  final VoidCallback? onPatchImage;
  final VoidCallback? onDeleteImage;
  final VoidCallback? onReloadBlocks;
  final VoidCallback? onRegisterBlock;
}

