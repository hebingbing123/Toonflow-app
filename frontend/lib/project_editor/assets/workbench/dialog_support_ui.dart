part of 'dialog_support.dart';

AlertDialog buildProjectAssetsWorkbenchDialog({
  required BuildContext dialogCtx,
  required bool localBusy,
  required bool assetsBusy,
  required String statusLine,
  required List<AssetRow> scopedAssets,
  required int? assetsFilterScriptNumericId,
  required AssetRow? selectedAsset,
  required List<AssetRow> assets,
  required List<ScriptBrief> scriptList,
  required int? selectedAssetNumericId,
  required int? selectedScriptNumericId,
  required ValueChanged<int?>? onAssetChanged,
  required ValueChanged<int?>? onScriptChanged,
  required Future<void> Function() onCreate,
  required Future<void> Function() onEdit,
  required Future<void> Function() onDelete,
  required Future<void> Function() onFilter,
  required Future<void> Function() onLink,
  required Future<void> Function() onUnlink,
  required Future<void> Function() onUploadEditImage,
  required Future<void> Function() onUploadClip,
  required Future<void> Function() onOpenImagesWorkbench,
  required Future<void> Function() onOpenGenerationWorkbench,
  required Future<void> Function() onOpenHistoryWorkbench,
  required VoidCallback? onRefresh,
  required VoidCallback? onClose,
}) {
  final viewportWidth = MediaQuery.sizeOf(dialogCtx).width;
  final dialogWidth = viewportWidth.isFinite
      ? viewportWidth.clamp(320.0, 780.0)
      : 780.0;
  final l10n = resolveAppLocalizationsForErrors(dialogCtx);
  return AlertDialog(
    title: Text(l10n.projectEditorAssetsMainWorkbenchTitle),
    content: SizedBox(
      width: dialogWidth,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.projectEditorAssetsMainWorkbenchDialogIntro,
              style: Theme.of(dialogCtx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _ProjectAssetsWorkbenchOverview(
              statusLine: statusLine,
              scriptScopedLine: summarizeScriptScopedAssets(
                assetsFilterScriptNumericId,
                scopedAssets,
              ),
              selectedAsset: selectedAsset,
              assets: assets,
              scriptList: scriptList,
              selectedAssetNumericId: selectedAssetNumericId,
              selectedScriptNumericId: selectedScriptNumericId,
              onAssetChanged: onAssetChanged,
              onScriptChanged: onScriptChanged,
            ),
            const SizedBox(height: 12),
            _ProjectAssetsWorkbenchActions(
              localBusy: localBusy,
              assetsBusy: assetsBusy,
              assets: assets,
              scriptList: scriptList,
              selectedScriptNumericId: selectedScriptNumericId,
              onCreate: onCreate,
              onEdit: onEdit,
              onDelete: onDelete,
              onFilter: onFilter,
              onLink: onLink,
              onUnlink: onUnlink,
              onUploadEditImage: onUploadEditImage,
              onUploadClip: onUploadClip,
            ),
            const SizedBox(height: 12),
            _ProjectAssetsWorkbenchLaunchers(
              localBusy: localBusy,
              assetsBusy: assetsBusy,
              onOpenImagesWorkbench: onOpenImagesWorkbench,
              onOpenGenerationWorkbench: onOpenGenerationWorkbench,
              onOpenHistoryWorkbench: onOpenHistoryWorkbench,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: onRefresh,
        child: Text(
          localBusy
              ? l10n.projectEditorAssetsMainWorkbenchRefreshBusy
              : l10n.projectEditorAssetsMainWorkbenchRefresh,
        ),
      ),
      TextButton(onPressed: onClose, child: Text(l10n.projectEditorAssetsMainWorkbenchClose)),
    ],
  );
}

