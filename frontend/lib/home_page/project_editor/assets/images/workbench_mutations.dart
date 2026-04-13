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

class _AssetImageMutationPlan {
  const _AssetImageMutationPlan({
    required this.requestPlan,
    required this.request,
  });

  final _AssetImageMutationRequestPlan requestPlan;
  final Future<void> Function() request;
}

const _createAssetImageRequestPlan = _AssetImageMutationRequestPlan(
  successSummary: '已新增资产图片。',
  failureSummary: '新增资产图片失败。',
  recommendedAction: AssetImagesWorkbenchRecommendedAction.createImage,
  fallbackDetail: '建议检查 file_path、state 或 sort_index 后重试。',
);

const _patchAssetImageRequestPlan = _AssetImageMutationRequestPlan(
  successSummary: '已更新当前图片。',
  failureSummary: '更新当前图片失败。',
  recommendedAction: AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
  fallbackDetail: '建议先重新读取预览，确认当前图片后再修改。',
);

const _deleteAssetImageRequestPlan = _AssetImageMutationRequestPlan(
  successSummary: '已删除当前图片。',
  failureSummary: '删除当前图片失败。',
  recommendedAction: AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
  fallbackDetail: '建议先刷新图片列表，确认当前选择后再删除。',
);

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

T? _resolveAssetImageDraft<T>({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required String invalidDraftNotice,
  required T? draft,
}) {
  if (draft == null) {
    setState(() => runtime.onStatusChanged(invalidDraftNotice));
    return null;
  }
  return draft;
}

AssetImageCreateDraft? _resolveCreateAssetImageDraft({
  required AssetImagesWorkbenchScope scope,
  required StateSetter setState,
}) {
  return _resolveAssetImageDraft(
    setState: setState,
    runtime: scope.runtime,
    invalidDraftNotice: '新增 sort_index 需为正整数',
    draft: parseAssetImageCreateDraft(
      filePath: scope.createControllers.filePathCtrl.text,
      state: scope.createControllers.stateCtrl.text,
      sortIndex: scope.createControllers.sortCtrl.text,
    ),
  );
}

AssetImagePatchDraft? _resolvePatchAssetImageDraft({
  required AssetImagesWorkbenchScope scope,
  required StateSetter setState,
}) {
  return _resolveAssetImageDraft(
    setState: setState,
    runtime: scope.runtime,
    invalidDraftNotice: '编辑 sort_index 需为正整数',
    draft: parseAssetImagePatchDraft(
      filePath: scope.patchControllers.filePathCtrl.text,
      state: scope.patchControllers.stateCtrl.text,
      sortIndex: scope.patchControllers.sortCtrl.text,
    ),
  );
}

_AssetImageMutationPlan? _buildCreateAssetImageMutationPlan({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) {
  final draft = _resolveCreateAssetImageDraft(scope: scope, setState: setState);
  if (draft == null) {
    return null;
  }
  return _AssetImageMutationPlan(
    requestPlan: _createAssetImageRequestPlan,
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

_SelectedAssetImageMutationPlan? _buildPatchAssetImageMutationPlan({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) {
  final draft = _resolvePatchAssetImageDraft(scope: scope, setState: setState);
  if (draft == null) {
    return null;
  }
  return _SelectedAssetImageMutationPlan(
    missingSelectionNotice: '请先选择要编辑的图片',
    requestPlan: _patchAssetImageRequestPlan,
    request: (image) => patchProjectAssetImageByProjectIds(
      scope.token,
      scope.projectId,
      assetNumericId,
      image.id,
      draft.body,
    ),
  );
}

_SelectedAssetImageMutationPlan _buildDeleteAssetImageMutationPlan({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
}) {
  return _SelectedAssetImageMutationPlan(
    missingSelectionNotice: '请先选择要删除的图片',
    requestPlan: _deleteAssetImageRequestPlan,
    request: (image) => deleteProjectAssetImageByProjectIds(
      scope.token,
      scope.projectId,
      assetNumericId,
      image.id,
    ),
  );
}

Future<void> _runSelectedAssetImageMutation({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
  required _SelectedAssetImageMutationPlan? plan,
}) async {
  if (plan == null) {
    return;
  }
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
  final plan = _buildCreateAssetImageMutationPlan(
    scope: scope,
    assetNumericId: assetNumericId,
    setState: setState,
  );
  if (plan == null) {
    return;
  }
  await _runAssetImageMutationPlan(
    scope: scope,
    assetNumericId: assetNumericId,
    setState: setState,
    plan: plan.requestPlan,
    request: plan.request,
  );
}

Future<void> patchAssetImage({
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
    plan: _buildPatchAssetImageMutationPlan(
      scope: scope,
      assetNumericId: assetNumericId,
      setState: setState,
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
    plan: _buildDeleteAssetImageMutationPlan(
      scope: scope,
      assetNumericId: assetNumericId,
    ),
  );
}
