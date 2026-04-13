part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesWorkbenchDialog on _HomePageState {
  /// 资产图片工作台的对话框主体，和请求流程分开，降低入口函数复杂度。
  AlertDialog _buildAssetImagesWorkbenchDialog({
    required BuildContext ctx,
    required BuildContext dialogCtx,
    required AssetImagesWorkbenchDialogState state,
    required AssetImagesWorkbenchDialogCallbacks callbacks,
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
              assets: state.assets,
              selectedAssetNumericId: state.selectedAssetNumericId,
              onAssetChanged: callbacks.onAssetChanged,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchDiagnosisCard(
              dialogCtx: dialogCtx,
              diagnosis: state.diagnosis,
              loadingList: state.loadingList,
              loadingPreview: state.loadingPreview,
              busyMutation: state.busyMutation,
              onRecommendedAction: callbacks.onRecommendedAction,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchToolbar(
              loadingList: state.loadingList,
              loadingPreview: state.loadingPreview,
              busyMutation: state.busyMutation,
              onReloadImages: callbacks.onReloadImages,
              onLoadPreview: callbacks.onLoadPreview,
            ),
            if (state.statusLine != null) ...[
              const SizedBox(height: 8),
              Text(state.statusLine!, style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchImageField(
              imageItems: state.imageItems,
              selectedImageId: state.selectedImageId,
              onImageChanged: callbacks.onImageChanged,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchCreateForm(
              controllers: state.createControllers,
              busyMutation: state.busyMutation,
              onCreateImage: callbacks.onCreateImage,
            ),
            _buildAssetImagesWorkbenchPatchForm(
              controllers: state.patchControllers,
              busyMutation: state.busyMutation,
              onPatchImage: callbacks.onPatchImage,
              onDeleteImage: callbacks.onDeleteImage,
            ),
            _buildAssetImagesWorkbenchPreview(state.previewBytes),
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
