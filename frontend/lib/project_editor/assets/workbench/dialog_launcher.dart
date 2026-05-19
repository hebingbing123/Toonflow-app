import 'package:flutter/material.dart';

import '../../../project_studio/project_studio_host.dart';
import '../../../rust_api.dart';
import '../support.dart';
import 'dialog_support.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

Future<void> openProjectAssetsWorkbenchDialog({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<ScriptBrief> scriptList,
  required List<ListAssetsResponse?> assetsRef,
  required List<ListAssetsResponse?> assetsForScriptRef,
  required List<int?> assetsFilterScriptNumericId,
  required List<bool> assetsBusy,
  required Future<void> Function() reloadAssetsAndStats,
  required Future<void> Function(BuildContext dialogCtx) onCreateAsset,
  required Future<void> Function(BuildContext dialogCtx) onEditAsset,
  required Future<void> Function(BuildContext dialogCtx) onDeleteAsset,
  required Future<void> Function(BuildContext dialogCtx) onFilterAssets,
  required Future<void> Function(BuildContext dialogCtx) onLinkAsset,
  required Future<void> Function(BuildContext dialogCtx) onUnlinkAsset,
  required Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onReviewCandidates,
  required Future<void> Function(BuildContext dialogCtx) onUploadEditImage,
  required Future<void> Function(BuildContext dialogCtx) onUploadClip,
  required Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenImagesWorkbench,
  required Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenGenerationWorkbench,
  required Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenHistoryWorkbench,
  int? initialSelectedAssetNumericId,
  int? initialSelectedScriptNumericId,
  String? initialFocusNotice,
  ProjectStudioAssetEditorTargetKind initialTargetKind =
      ProjectStudioAssetEditorTargetKind.overview,
}) async {
  final l10n = resolveAppLocalizationsForErrors(ctx);
  final visibleAssets = assetsRef[0]?.items ?? const <AssetRow>[];
  final initialSelectionAssets = assetsFilterScriptNumericId[0] == null
      ? visibleAssets
      : (assetsForScriptRef[0]?.items ?? visibleAssets);
  final initialStatusLine = visibleAssets.isEmpty
      ? l10n.projectEditorAssetsWorkbenchNoAssetsYet
      : summarizeProjectAssetRows(visibleAssets, l10n: l10n);
  final session = ProjectAssetsWorkbenchSession(
    visibleAssets: initialSelectionAssets,
    scriptList: scriptList,
    initialStatusLine: initialStatusLine,
    targetKind: initialTargetKind,
    focusNotice: initialFocusNotice,
    preferredAssetNumericId: initialSelectedAssetNumericId,
    preferredScriptNumericId: initialSelectedScriptNumericId,
  );
  final controller = ProjectAssetsWorkbenchController(
    ctx: ctx,
    token: token,
    project: project,
    setDialogState: setDialogState,
    scriptList: scriptList,
    assetsRef: assetsRef,
    assetsForScriptRef: assetsForScriptRef,
    assetsFilterScriptNumericId: assetsFilterScriptNumericId,
    assetsBusy: assetsBusy,
    reloadAssetsAndStats: reloadAssetsAndStats,
    session: session,
    onCreateAsset: onCreateAsset,
    onEditAsset: onEditAsset,
    onDeleteAsset: onDeleteAsset,
    onFilterAssets: onFilterAssets,
    onLinkAsset: onLinkAsset,
    onUnlinkAsset: onUnlinkAsset,
    onReviewCandidates: onReviewCandidates,
    onUploadEditImage: onUploadEditImage,
    onUploadClip: onUploadClip,
    onOpenImagesWorkbench: onOpenImagesWorkbench,
    onOpenGenerationWorkbench: onOpenGenerationWorkbench,
    onOpenHistoryWorkbench: onOpenHistoryWorkbench,
  );

  await showStudioDialog<void>(
    context: ctx,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (dialogCtx, setLocalState) {
          final assets = assetsRef[0]?.items ?? const <AssetRow>[];
          final selectedAsset = findAssetByNumericId(
            assets,
            session.selectedAssetNumericId,
          );
          final scopedAssets = assetsFilterScriptNumericId[0] == null
              ? assets
              : (assetsForScriptRef[0]?.items ?? const <AssetRow>[]);
          return buildProjectAssetsWorkbenchDialog(
            dialogCtx: dialogCtx,
            localBusy: session.localBusy,
            assetsBusy: assetsBusy[0],
            targetKind: session.targetKind,
            focusNotice: session.focusNotice,
            statusLine: session.statusLine,
            scopedAssets: scopedAssets,
            assetsFilterScriptNumericId: assetsFilterScriptNumericId[0],
            selectedAsset: selectedAsset,
            assets: assets,
            scriptList: scriptList,
            selectedAssetNumericId: session.selectedAssetNumericId,
            selectedScriptNumericId: session.selectedScriptNumericId,
            onAssetChanged: assets.isEmpty
                ? null
                : (value) {
                    setLocalState(() => session.selectedAssetNumericId = value);
                  },
            onScriptChanged: scriptList.isEmpty
                ? null
                : (value) {
                    setLocalState(
                      () => session.selectedScriptNumericId = value,
                    );
                  },
            onCreate: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onCreateAsset(dialogCtx),
            ),
            onEdit: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onEditAsset(dialogCtx),
            ),
            onDelete: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onDeleteAsset(dialogCtx),
            ),
            onFilter: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onFilterAssets(dialogCtx),
            ),
            onLink: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onLinkAsset(dialogCtx),
            ),
            onUnlink: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onUnlinkAsset(dialogCtx),
            ),
            onReviewCandidates: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onReviewCandidates(
                dialogCtx,
                session.selectedAssetNumericId,
              ),
            ),
            onUploadEditImage: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onUploadEditImage(dialogCtx),
            ),
            onUploadClip: () => controller.runWorkbenchAction(
              setLocalState: setLocalState,
              action: () => controller.onUploadClip(dialogCtx),
            ),
            onOpenImagesWorkbench: () => controller.openWorkbenchChildDialog(
              dialogCtx: dialogCtx,
              setLocalState: setLocalState,
              action: () => controller.onOpenImagesWorkbench(
                dialogCtx,
                session.selectedAssetNumericId,
              ),
            ),
            onOpenGenerationWorkbench: () =>
                controller.openWorkbenchChildDialog(
                  dialogCtx: dialogCtx,
                  setLocalState: setLocalState,
                  action: () => controller.onOpenGenerationWorkbench(
                    dialogCtx,
                    session.selectedAssetNumericId,
                  ),
                ),
            onOpenHistoryWorkbench: () => controller.openWorkbenchChildDialog(
              dialogCtx: dialogCtx,
              setLocalState: setLocalState,
              action: () => controller.onOpenHistoryWorkbench(
                dialogCtx,
                session.selectedAssetNumericId,
              ),
            ),
            onRefresh: session.localBusy
                ? null
                : () => controller.refreshWorkbench(setLocalState),
            onClose: session.localBusy
                ? null
                : () => Navigator.of(dialogCtx).pop(),
          );
        },
      );
    },
  );
}
