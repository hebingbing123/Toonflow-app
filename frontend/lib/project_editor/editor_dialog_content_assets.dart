part of '../../home_page.dart';

extension _HomePageProjectEditorDialogContentAssets on _HomePageState {
  Widget _buildProjectEditorAssetsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required _ProjectEditorDialogState dialogState,
    required List<ScriptBrief> scriptList,
  }) {
    return buildProjectAssetsSection(
      ctx: ctx,
      setDialogState: setDialogState,
      token: token,
      project: p,
      scriptList: scriptList,
      assetsRef: dialogState.assetsRef,
      assetsForScriptRef: dialogState.assetsForScriptRef,
      assetsFilterScriptNumericId: dialogState.assetsFilterScriptNumericId,
      assetsFocusNoticeRef: dialogState.assetsFocusNotice,
      assetsLoading: dialogState.assetsLoading,
      assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
      assetsBusy: dialogState.assetsBusy,
      reloadAssetsAndStats: () =>
          dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
      buildImagesSection: () => _buildProjectAssetsImagesCompatibilitySection(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        assetsRef: dialogState.assetsRef,
        assetsLoading: dialogState.assetsLoading,
        assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
        assetsBusy: dialogState.assetsBusy,
        reloadAssetsAndStats: () =>
            dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
      ),
      buildPrimaryActions: () => _buildProjectAssetsPrimaryActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        assetsRef: dialogState.assetsRef,
        assetsFilterScriptNumericId: dialogState.assetsFilterScriptNumericId,
        assetsLoading: dialogState.assetsLoading,
        assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
        assetsBusy: dialogState.assetsBusy,
        reloadAssetsAndStats: () =>
            dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
      ),
      buildRelationActions: () => _buildProjectAssetsRelationActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        scriptList: scriptList,
        assetsRef: dialogState.assetsRef,
        assetsLoading: dialogState.assetsLoading,
        assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
        assetsBusy: dialogState.assetsBusy,
        reloadAssetsAndStats: () =>
            dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
      ),
      buildQueryActions: () => _buildProjectAssetsQueryCompatibilityActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        assetsRef: dialogState.assetsRef,
        assetsFilterScriptNumericId: dialogState.assetsFilterScriptNumericId,
        assetsLoading: dialogState.assetsLoading,
        assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
        assetsBusy: dialogState.assetsBusy,
        reloadAssetsAndStats: () =>
            dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
      ),
      openWorkbench: () => openProjectAssetsWorkbenchDialog(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        project: p,
        scriptList: scriptList,
        assetsRef: dialogState.assetsRef,
        assetsForScriptRef: dialogState.assetsForScriptRef,
        assetsFilterScriptNumericId: dialogState.assetsFilterScriptNumericId,
        assetsBusy: dialogState.assetsBusy,
        reloadAssetsAndStats: () =>
            dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
        onCreateAsset: (dialogCtx) => _openCreateAssetDialog(
          ctx: dialogCtx,
          setDialogState: setDialogState,
          token: token,
          p: p,
          assetsBusy: dialogState.assetsBusy,
          reloadAssetsAndStats: () =>
              dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
        ),
        onEditAsset: (dialogCtx) => _openEditAssetDialog(
          ctx: dialogCtx,
          setDialogState: setDialogState,
          token: token,
          p: p,
          assetsRef: dialogState.assetsRef,
          assetsBusy: dialogState.assetsBusy,
          reloadAssetsAndStats: () =>
              dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
        ),
        onDeleteAsset: (dialogCtx) => _openDeleteAssetDialog(
          ctx: dialogCtx,
          setDialogState: setDialogState,
          token: token,
          p: p,
          assetsRef: dialogState.assetsRef,
          assetsBusy: dialogState.assetsBusy,
          reloadAssetsAndStats: () =>
              dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
        ),
        onFilterAssets: (dialogCtx) => _openAssetFilterDialog(
          ctx: dialogCtx,
          setDialogState: setDialogState,
          token: token,
          p: p,
          scriptList: scriptList,
          assetsRef: dialogState.assetsRef,
          assetsForScriptRef: dialogState.assetsForScriptRef,
          assetsFilterScriptNumericId: dialogState.assetsFilterScriptNumericId,
          assetsBusy: dialogState.assetsBusy,
        ),
        onLinkAsset: (dialogCtx) => openProjectAssetLinkDialog(
          ctx: dialogCtx,
          setDialogState: setDialogState,
          token: token,
          project: p,
          scriptList: scriptList,
          assetsRef: dialogState.assetsRef,
          assetsBusy: dialogState.assetsBusy,
          reloadAssetsAndStats: () =>
              dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
          unlink: false,
        ),
        onUnlinkAsset: (dialogCtx) => openProjectAssetLinkDialog(
          ctx: dialogCtx,
          setDialogState: setDialogState,
          token: token,
          project: p,
          scriptList: scriptList,
          assetsRef: dialogState.assetsRef,
          assetsBusy: dialogState.assetsBusy,
          reloadAssetsAndStats: () =>
              dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
          unlink: true,
        ),
        onReviewCandidates: (dialogCtx, preferredAssetNumericId) =>
            _openCandidateStatusDialog(
              ctx: dialogCtx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              assetsRef: dialogState.assetsRef,
              assetsBusy: dialogState.assetsBusy,
              reloadAssetsAndStats: () =>
                  dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
              preferredAssetNumericId: preferredAssetNumericId,
            ),
        onUploadEditImage: (dialogCtx) => openProjectAssetEditImageUploadDialog(
          ctx: dialogCtx,
          setDialogState: setDialogState,
          token: token,
          project: p,
          scriptList: scriptList,
          assetsBusy: dialogState.assetsBusy,
        ),
        onUploadClip: (dialogCtx) => openProjectAssetClipUploadDialog(
          ctx: dialogCtx,
          setDialogState: setDialogState,
          token: token,
          project: p,
          assetsBusy: dialogState.assetsBusy,
          reloadAssetsAndStats: () =>
              dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
        ),
        onOpenGenerationWorkbench: (dialogCtx, preferredAssetNumericId) =>
            openAssetGenerationWorkbenchDialog(
              ctx: dialogCtx,
              setDialogState: setDialogState,
              token: token,
              project: p,
              scriptList: scriptList,
              assetsRef: dialogState.assetsRef,
              assetsForScriptRef: dialogState.assetsForScriptRef,
              assetsFilterScriptNumericId:
                  dialogState.assetsFilterScriptNumericId,
              assetsBusy: dialogState.assetsBusy,
              reloadAssetsAndStats: () =>
                  dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
              preferredAssetNumericId: preferredAssetNumericId,
            ),
        onOpenHistoryWorkbench: (dialogCtx, preferredAssetNumericId) =>
            openCornerScapeWorkbenchDialog(
              ctx: dialogCtx,
              setDialogState: setDialogState,
              token: token,
              project: p,
              assetsBusy: dialogState.assetsBusy,
              preferredAssetNumericId: preferredAssetNumericId,
            ),
        onOpenImagesWorkbench: (dialogCtx, preferredAssetNumericId) =>
            openAssetImagesWorkbenchDialog(
              ctx: dialogCtx,
              setDialogState: setDialogState,
              token: token,
              project: p,
              assetsRef: dialogState.assetsRef,
              assetsBusy: dialogState.assetsBusy,
              reloadAssetsAndStats: () =>
                  dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
              preferredAssetNumericId: preferredAssetNumericId,
            ),
      ),
    );
  }
}
