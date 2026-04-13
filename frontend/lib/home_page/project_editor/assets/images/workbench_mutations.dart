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

Future<void> _runAssetImageMutationRequest({
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
  required String failureSummary,
  required AssetImagesWorkbenchRecommendedAction recommendedAction,
  required String fallbackDetail,
  required Future<void> Function() request,
}) async {
  try {
    await request();
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
      successSummary: successSummary,
    );
  } on RustApiException catch (e) {
    _setAssetImageMutationFailure(
      setState: setState,
      runtime: runtime,
      actionSummary: failureSummary,
      recommendedAction: recommendedAction,
      error: e,
      fallbackDetail: fallbackDetail,
    );
  }
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

AssetImageRow? _requireSelectedAssetImage({
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required String missingSelectionNotice,
}) {
  final image = selectedAssetImageRow(
    imagesResponse,
    selectedImageId: selectedImageId,
  );
  if (image != null) {
    return image;
  }
  setState(() => runtime.onStatusChanged(missingSelectionNotice));
  return null;
}

Map<String, dynamic>? _buildPatchAssetImageBody({
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
}) {
  final body = <String, dynamic>{
    'file_path': _optionalWorkbenchText(patchFilePathCtrl),
    'state': _optionalWorkbenchText(patchStateCtrl),
  };
  final sortRaw = patchSortCtrl.text.trim();
  if (sortRaw.isEmpty) {
    return body;
  }
  final sort = parsePositiveWorkbenchInt(sortRaw);
  if (sort == null) {
    setState(() => runtime.onStatusChanged('编辑 sort_index 需为正整数'));
    return null;
  }
  body['sort_index'] = sort;
  return body;
}

String? _optionalWorkbenchText(TextEditingController controller) {
  final value = controller.text.trim();
  return value.isEmpty ? null : value;
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
      await _runAssetImageMutationRequest(
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
        failureSummary: '新增资产图片失败。',
        recommendedAction: AssetImagesWorkbenchRecommendedAction.createImage,
        fallbackDetail: '建议检查 file_path、state 或 sort_index 后重试。',
        request: () => createProjectAssetImageForProject(
          token,
          projectId,
          assetNumericId,
          filePath: _optionalWorkbenchText(createFilePathCtrl),
          state: _optionalWorkbenchText(createStateCtrl),
          sortIndex: sort,
        ),
      );
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
  final image = _requireSelectedAssetImage(
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    setState: setState,
    runtime: runtime,
    missingSelectionNotice: '请先选择要编辑的图片',
  );
  if (image == null) {
    return;
  }
  final body = _buildPatchAssetImageBody(
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
    setState: setState,
    runtime: runtime,
  );
  if (body == null) {
    return;
  }
  await _runAssetImageMutation(
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    action: () async {
      await _runAssetImageMutationRequest(
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
        failureSummary: '更新当前图片失败。',
        recommendedAction:
            AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
        fallbackDetail: '建议先重新读取预览，确认当前图片后再修改。',
        request: () => patchProjectAssetImageByProjectIds(
          token,
          projectId,
          assetNumericId,
          image.id,
          body,
        ),
      );
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
  final image = _requireSelectedAssetImage(
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    setState: setState,
    runtime: runtime,
    missingSelectionNotice: '请先选择要删除的图片',
  );
  if (image == null) {
    return;
  }
  await _runAssetImageMutation(
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    action: () async {
      await _runAssetImageMutationRequest(
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
        failureSummary: '删除当前图片失败。',
        recommendedAction:
            AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
        fallbackDetail: '建议先刷新图片列表，确认当前选择后再删除。',
        request: () => deleteProjectAssetImageByProjectIds(
          token,
          projectId,
          assetNumericId,
          image.id,
        ),
      );
    },
  );
}
