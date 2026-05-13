part of 'workbench_support.dart';

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
        l10n: scope.mutation.l10n,
        actionSummary: successSummary,
        diagnosis: scope.runtime.diagnose(scope.mutation.l10n),
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
  } catch (e) {
    _setAssetImageMutationFailure(
      l10n: scope.mutation.l10n,
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
  required AppLocalizations l10n,
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
        l10n: l10n,
        actionSummary: actionSummary,
        recommendedAction: recommendedAction,
        error: error,
        fallbackDetail: fallbackDetail,
      ),
    );
  });
}

void _setAssetImageMutationStatus({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required String statusLine,
}) {
  setState(() => runtime.onStatusChanged(statusLine));
}

T? _resolveAssetImageMutationValue<T>({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required String emptyValueNotice,
  required T? value,
}) {
  if (value == null) {
    _setAssetImageMutationStatus(
      setState: setState,
      runtime: runtime,
      statusLine: emptyValueNotice,
    );
    return null;
  }
  return value;
}

AssetImageRow? _resolveSelectedAssetImage({
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required String missingSelectionNotice,
}) {
  return _resolveAssetImageMutationValue(
    setState: setState,
    runtime: runtime,
    emptyValueNotice: missingSelectionNotice,
    value: selectedAssetImageRow(
      imagesResponse,
      selectedImageId: selectedImageId,
    ),
  );
}

AssetImageCreateDraft? _resolveCreateAssetImageDraft({
  required AssetImagesWorkbenchScope scope,
  required StateSetter setState,
}) {
  return _resolveAssetImageMutationValue(
    setState: setState,
    runtime: scope.runtime,
    emptyValueNotice: scope.mutation.l10n.projectEditorAssetImagesCreateSortMustBePositive,
    value: parseAssetImageCreateDraft(
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
  return _resolveAssetImageMutationValue(
    setState: setState,
    runtime: scope.runtime,
    emptyValueNotice: scope.mutation.l10n.projectEditorAssetImagesPatchSortMustBePositive,
    value: parseAssetImagePatchDraft(
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
    requestPlan: _createAssetImageRequestPlan(scope.mutation.l10n),
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

_SelectedAssetImageMutationPlan _buildSelectedAssetImageMutationPlan({
  required String missingSelectionNotice,
  required _AssetImageMutationRequestPlan requestPlan,
  required Future<void> Function(AssetImageRow image) request,
}) {
  return _SelectedAssetImageMutationPlan(
    missingSelectionNotice: missingSelectionNotice,
    requestPlan: requestPlan,
    request: request,
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
  return _buildSelectedAssetImageMutationPlan(
    missingSelectionNotice: scope.mutation.l10n.projectEditorAssetImagesSelectImageToEdit,
    requestPlan: _patchAssetImageRequestPlan(scope.mutation.l10n),
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
  return _buildSelectedAssetImageMutationPlan(
    missingSelectionNotice: scope.mutation.l10n.projectEditorAssetImagesSelectImageToDelete,
    requestPlan: _deleteAssetImageRequestPlan(scope.mutation.l10n),
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
  final image = _resolveSelectedAssetImage(
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

