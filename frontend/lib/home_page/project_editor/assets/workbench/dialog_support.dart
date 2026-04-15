import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import '../support.dart';

part 'dialog_actions.dart';
part 'dialog_view.dart';

class ProjectAssetsWorkbenchSession {
  ProjectAssetsWorkbenchSession({
    required List<AssetRow> visibleAssets,
    required List<ScriptBrief> scriptList,
  }) : selectedAssetNumericId = chooseInitialAssetNumericId(visibleAssets),
       selectedScriptNumericId = scriptList.isEmpty
           ? null
           : scriptList.first.numericId,
       statusLine = visibleAssets.isEmpty
           ? '当前项目还没有资产，可直接在这里创建。'
           : summarizeProjectAssetRows(visibleAssets);

  int? selectedAssetNumericId;
  int? selectedScriptNumericId;
  String statusLine;
  bool localBusy = false;
}

class ProjectAssetsWorkbenchController {
  const ProjectAssetsWorkbenchController({
    required this.ctx,
    required this.token,
    required this.project,
    required this.setDialogState,
    required this.scriptList,
    required this.assetsRef,
    required this.assetsForScriptRef,
    required this.assetsFilterScriptNumericId,
    required this.assetsBusy,
    required this.reloadAssetsAndStats,
    required this.session,
    required this.onCreateAsset,
    required this.onEditAsset,
    required this.onDeleteAsset,
    required this.onFilterAssets,
    required this.onLinkAsset,
    required this.onUnlinkAsset,
    required this.onUploadEditImage,
    required this.onUploadClip,
    required this.onOpenImagesWorkbench,
    required this.onOpenGenerationWorkbench,
    required this.onOpenHistoryWorkbench,
  });

  final BuildContext ctx;
  final String token;
  final ProjectRow project;
  final StateSetter setDialogState;
  final List<ScriptBrief> scriptList;
  final List<ListAssetsResponse?> assetsRef;
  final List<ListAssetsResponse?> assetsForScriptRef;
  final List<int?> assetsFilterScriptNumericId;
  final List<bool> assetsBusy;
  final Future<void> Function() reloadAssetsAndStats;
  final ProjectAssetsWorkbenchSession session;
  final Future<void> Function(BuildContext dialogCtx) onCreateAsset;
  final Future<void> Function(BuildContext dialogCtx) onEditAsset;
  final Future<void> Function(BuildContext dialogCtx) onDeleteAsset;
  final Future<void> Function(BuildContext dialogCtx) onFilterAssets;
  final Future<void> Function(BuildContext dialogCtx) onLinkAsset;
  final Future<void> Function(BuildContext dialogCtx) onUnlinkAsset;
  final Future<void> Function(BuildContext dialogCtx) onUploadEditImage;
  final Future<void> Function(BuildContext dialogCtx) onUploadClip;
  final Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenImagesWorkbench;
  final Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenGenerationWorkbench;
  final Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenHistoryWorkbench;

  Future<void> refreshWorkbench(StateSetter setLocalState) =>
      refreshProjectAssetsWorkbench(
        reloadAssetsAndStats: reloadAssetsAndStats,
        assetsRef: assetsRef,
        selectedAssetNumericId: session.selectedAssetNumericId,
        onSelectedAssetNumericIdChanged: (value) =>
            session.selectedAssetNumericId = value,
        onStatusLineChanged: (line) => session.statusLine = line,
        setLocalState: setLocalState,
      );

  Future<void> runWorkbenchAction({
    required StateSetter setLocalState,
    required Future<void> Function() action,
  }) => runAction(
    ctx: ctx,
    setLocalState: setLocalState,
    onBusyChanged: (busy) => session.localBusy = busy,
    refreshWorkbench: () => refreshWorkbench(setLocalState),
    action: action,
  );

  Future<void> openWorkbenchChildDialog({
    required BuildContext dialogCtx,
    required StateSetter setLocalState,
    required Future<void> Function() action,
  }) => openChildWorkbench(
    parentCtx: ctx,
    dialogCtx: dialogCtx,
    refreshWorkbench: () => refreshWorkbench(setLocalState),
    action: action,
  );
}
