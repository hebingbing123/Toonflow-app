part of '../../../../home_page.dart';

class _AssetImageMutationRequestPlan {
  const _AssetImageMutationRequestPlan({
    required this.successSummary,
    required this.failureSummary,
    required this.recommendedAction,
    required this.fallbackDetail,
  });

  final String successSummary;
  final String failureSummary;
  final AssetImagesWorkbenchRecommendedAction recommendedAction;
  final String fallbackDetail;
}

class _SelectedAssetImageMutationPlan {
  const _SelectedAssetImageMutationPlan({
    required this.missingSelectionNotice,
    required this.requestPlan,
    required this.request,
  });

  final String missingSelectionNotice;
  final _AssetImageMutationRequestPlan requestPlan;
  final Future<void> Function(AssetImageRow image) request;
}

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
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
  required String successSummary,
}) async {
  await reloadAssetImages(
    scope: scope,
    assetNumericId: assetNumericId,
    setState: setState,
  );
  await scope.mutation.reloadAssetsAndStats();
  setState(() {
    scope.runtime.onStatusChanged(
      buildAssetImagesWorkbenchFollowUp(
        actionSummary: successSummary,
        diagnosis: scope.runtime.diagnose(),
      ),
    );
  });
}

Future<void> _runAssetImageMutationRequest({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
  required _AssetImageMutationRequestPlan plan,
  required Future<void> Function() request,
}) async {
  try {
    await request();
    await _finishAssetImageMutation(
      scope: scope,
      assetNumericId: assetNumericId,
      setState: setState,
      successSummary: plan.successSummary,
    );
  } on RustApiException catch (e) {
    _setAssetImageMutationFailure(
      setState: setState,
      runtime: scope.runtime,
      actionSummary: plan.failureSummary,
      recommendedAction: plan.recommendedAction,
      error: e,
      fallbackDetail: plan.fallbackDetail,
    );
  }
}

Future<void> _runAssetImageMutationPlan({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
  required _AssetImageMutationRequestPlan plan,
  required Future<void> Function() request,
}) async {
  await _runAssetImageMutation(
    setState: setState,
    ctx: scope.mutation.ctx,
    setDialogState: scope.mutation.setDialogState,
    assetsBusy: scope.mutation.assetsBusy,
    onBusyMutationChanged: scope.mutation.onBusyMutationChanged,
    action: () async {
      await _runAssetImageMutationRequest(
        scope: scope,
        assetNumericId: assetNumericId,
        setState: setState,
        plan: plan,
        request: request,
      );
    },
  );
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
  required AssetImagesWorkbenchFormControllers patchControllers,
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
}) {
  final draft = parseAssetImagePatchDraft(
    filePath: patchControllers.filePathCtrl.text,
    state: patchControllers.stateCtrl.text,
    sortIndex: patchControllers.sortCtrl.text,
  );
  if (draft == null) {
    setState(() => runtime.onStatusChanged('编辑 sort_index 需为正整数'));
    return null;
  }
  return draft.body;
}

Future<void> _runSelectedAssetImageMutation({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
  required _SelectedAssetImageMutationPlan plan,
}) async {
  final image = _requireSelectedAssetImage(
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    setState: setState,
    runtime: scope.runtime,
    missingSelectionNotice: plan.missingSelectionNotice,
  );
  if (image == null) {
    return;
  }
  await _runAssetImageMutationPlan(
    scope: scope,
    assetNumericId: assetNumericId,
    setState: setState,
    plan: plan.requestPlan,
    request: () => plan.request(image),
  );
}

Future<void> createAssetImage({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  final draft = parseAssetImageCreateDraft(
    filePath: scope.createControllers.filePathCtrl.text,
    state: scope.createControllers.stateCtrl.text,
    sortIndex: scope.createControllers.sortCtrl.text,
  );
  if (draft == null) {
    setState(() => scope.runtime.onStatusChanged('新增 sort_index 需为正整数'));
    return;
  }
  await _runAssetImageMutationPlan(
    scope: scope,
    assetNumericId: assetNumericId,
    setState: setState,
    plan: const _AssetImageMutationRequestPlan(
      successSummary: '已新增资产图片。',
      failureSummary: '新增资产图片失败。',
      recommendedAction: AssetImagesWorkbenchRecommendedAction.createImage,
      fallbackDetail: '建议检查 file_path、state 或 sort_index 后重试。',
    ),
    request: () => createProjectAssetImageForProject(
      scope.token,
      scope.projectId,
      assetNumericId,
      filePath: draft.filePath,
      state: draft.state,
      sortIndex: draft.sortIndex,
    ),
  );
}

Future<void> patchAssetImage({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
}) async {
  final body = _buildPatchAssetImageBody(
    patchControllers: scope.patchControllers,
    setState: setState,
    runtime: scope.runtime,
  );
  if (body == null) {
    return;
  }
  await _runSelectedAssetImageMutation(
    scope: scope,
    assetNumericId: assetNumericId,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    setState: setState,
    plan: _SelectedAssetImageMutationPlan(
      missingSelectionNotice: '请先选择要编辑的图片',
      requestPlan: const _AssetImageMutationRequestPlan(
        successSummary: '已更新当前图片。',
        failureSummary: '更新当前图片失败。',
        recommendedAction:
            AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
        fallbackDetail: '建议先重新读取预览，确认当前图片后再修改。',
      ),
      request: (image) => patchProjectAssetImageByProjectIds(
          scope.token,
          scope.projectId,
          assetNumericId,
          image.id,
          body,
        ),
    ),
  );
}

Future<void> deleteAssetImage({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
}) async {
  await _runSelectedAssetImageMutation(
    scope: scope,
    assetNumericId: assetNumericId,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    setState: setState,
    plan: _SelectedAssetImageMutationPlan(
      missingSelectionNotice: '请先选择要删除的图片',
      requestPlan: const _AssetImageMutationRequestPlan(
        successSummary: '已删除当前图片。',
        failureSummary: '删除当前图片失败。',
        recommendedAction:
            AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
        fallbackDetail: '建议先刷新图片列表，确认当前选择后再删除。',
      ),
      request: (image) => deleteProjectAssetImageByProjectIds(
          scope.token,
          scope.projectId,
          assetNumericId,
          image.id,
        ),
    ),
  );
}
