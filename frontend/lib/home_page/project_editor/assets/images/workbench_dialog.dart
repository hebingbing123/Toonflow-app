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
            _buildAssetImagesWorkbenchAssetField(
              assets: assets,
              selectedAssetNumericId: selectedAssetNumericId,
              onAssetChanged: onAssetChanged,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchDiagnosisCard(
              dialogCtx: dialogCtx,
              diagnosis: diagnosis,
              loadingList: loadingList,
              loadingPreview: loadingPreview,
              busyMutation: busyMutation,
              onRecommendedAction: onRecommendedAction,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchToolbar(
              loadingList: loadingList,
              loadingPreview: loadingPreview,
              busyMutation: busyMutation,
              onReloadImages: onReloadImages,
              onLoadPreview: onLoadPreview,
            ),
            if (statusLine != null) ...[
              const SizedBox(height: 8),
              Text(statusLine, style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchImageField(
              imageItems: imageItems,
              selectedImageId: selectedImageId,
              onImageChanged: onImageChanged,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchCreateForm(
              createFilePathCtrl: createFilePathCtrl,
              createStateCtrl: createStateCtrl,
              createSortCtrl: createSortCtrl,
              busyMutation: busyMutation,
              onCreateImage: onCreateImage,
            ),
            _buildAssetImagesWorkbenchPatchForm(
              patchFilePathCtrl: patchFilePathCtrl,
              patchStateCtrl: patchStateCtrl,
              patchSortCtrl: patchSortCtrl,
              busyMutation: busyMutation,
              onPatchImage: onPatchImage,
              onDeleteImage: onDeleteImage,
            ),
            _buildAssetImagesWorkbenchPreview(previewBytes),
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
