part of '../../../../home_page.dart';

Future<void> _runAssetImageMutation({
  required StateSetter setState,
  required BuildContext ctx,
  required StateSetter setDialogState,
  required List<bool> assetsBusy,
  required ValueChanged<bool> onBusyMutationChanged,
  required Future<void> Function() action,
}) async {
  setDialogState(() => assetsBusy[0] = true);
  setState(() => onBusyMutationChanged(true));
  try {
    await action();
  } finally {
    setState(() => onBusyMutationChanged(false));
    if (ctx.mounted) {
      setDialogState(() => assetsBusy[0] = false);
    }
  }
}

Future<void> _finishAssetImageMutation({
  required String token,
  required String projectId,
  required int assetNumericId,
  required AssetImagesWorkbenchRuntime runtime,
  required StateSetter setState,
  required Future<void> Function() reloadAssetsAndStats,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
  required String successSummary,
}) async {
  await reloadAssetImages(
    token: token,
    projectId: projectId,
    assetNumericId: assetNumericId,
    runtime: runtime,
    setState: setState,
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );
  await reloadAssetsAndStats();
  setState(() {
    runtime.onStatusChanged(
      buildAssetImagesWorkbenchFollowUp(
        actionSummary: successSummary,
        diagnosis: runtime.diagnose(),
      ),
    );
  });
}

void _setAssetImageMutationFailure({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required String actionSummary,
  required AssetImagesWorkbenchRecommendedAction recommendedAction,
  required Object error,
  required String fallbackDetail,
}) {
  setState(() {
    runtime.onStatusChanged(
      buildAssetImagesWorkbenchFailureNotice(
        actionSummary: actionSummary,
        recommendedAction: recommendedAction,
        error: error,
        fallbackDetail: fallbackDetail,
      ),
    );
  });
}

Future<void> createAssetImage({
  required String token,
  required String projectId,
  required int assetNumericId,
  required TextEditingController createFilePathCtrl,
  required TextEditingController createStateCtrl,
  required TextEditingController createSortCtrl,
  required StateSetter setState,
  required BuildContext ctx,
  required StateSetter setDialogState,
  required List<bool> assetsBusy,
  required ValueChanged<bool> onBusyMutationChanged,
  required Future<void> Function() reloadAssetsAndStats,
  required AssetImagesWorkbenchRuntime runtime,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
}) async {
  final filePath = createFilePathCtrl.text.trim();
  final state = createStateCtrl.text.trim();
  final sort = parsePositiveWorkbenchInt(createSortCtrl.text);
  if (createSortCtrl.text.trim().isNotEmpty && sort == null) {
    setState(() => runtime.onStatusChanged('新增 sort_index 需为正整数'));
    return;
  }
  await _runAssetImageMutation(
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    action: () async {
      try {
        await createProjectAssetImageForProject(
          token,
          projectId,
          assetNumericId,
          filePath: filePath.isEmpty ? null : filePath,
          state: state.isEmpty ? null : state,
          sortIndex: sort,
        );
        await _finishAssetImageMutation(
          token: token,
          projectId: projectId,
          assetNumericId: assetNumericId,
          runtime: runtime,
          setState: setState,
          reloadAssetsAndStats: reloadAssetsAndStats,
          patchFilePathCtrl: patchFilePathCtrl,
          patchStateCtrl: patchStateCtrl,
          patchSortCtrl: patchSortCtrl,
          successSummary: '已新增资产图片。',
        );
      } on RustApiException catch (e) {
        _setAssetImageMutationFailure(
          setState: setState,
          runtime: runtime,
          actionSummary: '新增资产图片失败。',
          recommendedAction: AssetImagesWorkbenchRecommendedAction.createImage,
          error: e,
          fallbackDetail: '建议检查 file_path、state 或 sort_index 后重试。',
        );
      }
    },
  );
}

Future<void> patchAssetImage({
  required String token,
  required String projectId,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
  required StateSetter setState,
  required BuildContext ctx,
  required StateSetter setDialogState,
  required List<bool> assetsBusy,
  required ValueChanged<bool> onBusyMutationChanged,
  required Future<void> Function() reloadAssetsAndStats,
  required AssetImagesWorkbenchRuntime runtime,
}) async {
  final image = selectedAssetImageRow(
    imagesResponse,
    selectedImageId: selectedImageId,
  );
  if (image == null) {
    setState(() => runtime.onStatusChanged('请先选择要编辑的图片'));
    return;
  }
  final body = <String, dynamic>{};
  final filePath = patchFilePathCtrl.text.trim();
  final state = patchStateCtrl.text.trim();
  final sortRaw = patchSortCtrl.text.trim();
  body['file_path'] = filePath.isNotEmpty ? filePath : null;
  body['state'] = state.isNotEmpty ? state : null;
  if (sortRaw.isNotEmpty) {
    final sort = parsePositiveWorkbenchInt(sortRaw);
    if (sort == null) {
      setState(() => runtime.onStatusChanged('编辑 sort_index 需为正整数'));
      return;
    }
    body['sort_index'] = sort;
  }
  await _runAssetImageMutation(
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    action: () async {
      try {
        await patchProjectAssetImageByProjectIds(
          token,
          projectId,
          assetNumericId,
          image.id,
          body,
        );
        await _finishAssetImageMutation(
          token: token,
          projectId: projectId,
          assetNumericId: assetNumericId,
          runtime: runtime,
          setState: setState,
          reloadAssetsAndStats: reloadAssetsAndStats,
          patchFilePathCtrl: patchFilePathCtrl,
          patchStateCtrl: patchStateCtrl,
          patchSortCtrl: patchSortCtrl,
          successSummary: '已更新当前图片。',
        );
      } on RustApiException catch (e) {
        _setAssetImageMutationFailure(
          setState: setState,
          runtime: runtime,
          actionSummary: '更新当前图片失败。',
          recommendedAction:
              AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
          error: e,
          fallbackDetail: '建议先重新读取预览，确认当前图片后再修改。',
        );
      }
    },
  );
}

Future<void> deleteAssetImage({
  required String token,
  required String projectId,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
  required BuildContext ctx,
  required StateSetter setDialogState,
  required List<bool> assetsBusy,
  required ValueChanged<bool> onBusyMutationChanged,
  required Future<void> Function() reloadAssetsAndStats,
  required AssetImagesWorkbenchRuntime runtime,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
}) async {
  final image = selectedAssetImageRow(
    imagesResponse,
    selectedImageId: selectedImageId,
  );
  if (image == null) {
    setState(() => runtime.onStatusChanged('请先选择要删除的图片'));
    return;
  }
  await _runAssetImageMutation(
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    action: () async {
      try {
        await deleteProjectAssetImageByProjectIds(
          token,
          projectId,
          assetNumericId,
          image.id,
        );
        await _finishAssetImageMutation(
          token: token,
          projectId: projectId,
          assetNumericId: assetNumericId,
          runtime: runtime,
          setState: setState,
          reloadAssetsAndStats: reloadAssetsAndStats,
          patchFilePathCtrl: patchFilePathCtrl,
          patchStateCtrl: patchStateCtrl,
          patchSortCtrl: patchSortCtrl,
          successSummary: '已删除当前图片。',
        );
      } on RustApiException catch (e) {
        _setAssetImageMutationFailure(
          setState: setState,
          runtime: runtime,
          actionSummary: '删除当前图片失败。',
          recommendedAction:
              AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
          error: e,
          fallbackDetail: '建议先刷新图片列表，确认当前选择后再删除。',
        );
      }
    },
  );
}
