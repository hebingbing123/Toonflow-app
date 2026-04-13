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
              state: state,
              callbacks: callbacks,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchDiagnosisCard(
              dialogCtx: dialogCtx,
              state: state,
              callbacks: callbacks,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchToolbar(
              state: state,
              callbacks: callbacks,
            ),
            if (state.statusLine != null) ...[
              const SizedBox(height: 8),
              Text(state.statusLine!, style: Theme.of(ctx).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchImageField(
              state: state,
              callbacks: callbacks,
            ),
            const SizedBox(height: 8),
            _buildAssetImagesWorkbenchCreateForm(
              state: state,
              callbacks: callbacks,
            ),
            _buildAssetImagesWorkbenchPatchForm(
              state: state,
              callbacks: callbacks,
            ),
            _buildAssetImagesWorkbenchPreview(state: state),
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
