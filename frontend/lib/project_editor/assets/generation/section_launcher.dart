import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../rust_api.dart';
import '../support.dart';
import 'dialog.dart';
import 'support.dart';

Future<void> openAssetGenerationWorkbenchDialog({
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
  int? preferredAssetNumericId,
}) async {
  List<AssetRow> visibleAssets() {
    final filtered = assetsFilterScriptNumericId[0] == null
        ? null
        : assetsForScriptRef[0];
    return (filtered ?? assetsRef[0])?.items ?? const <AssetRow>[];
  }

  final seededAssets = visibleAssets();
  final l10n = AppLocalizations.of(ctx)!;
  if (seededAssets.isEmpty) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetGenWorkbenchNeedAssetsSnack)));
    return;
  }
  if (scriptList.isEmpty) {
    ScaffoldMessenger.of(
      ctx,
    ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetGenWorkbenchNeedScriptSnack)));
    return;
  }

  final initialFocusedAssetNumericId = chooseInitialAssetNumericId(
    seededAssets,
    preferredNumericId: preferredAssetNumericId,
  );
  final initialSelectedIds = chooseVisibleAssetSelection(
    seededAssets,
    preferredNumericId: initialFocusedAssetNumericId,
  );

  await showDialog<void>(
    context: ctx,
    builder: (dialogCtx) {
      return AssetGenerationWorkbenchDialog(
        token: token,
        project: project,
        scriptList: scriptList,
        visibleAssets: visibleAssets,
        assetsFilterScriptNumericId: assetsFilterScriptNumericId,
        initialSelectedIds: initialSelectedIds,
        initialFocusedAssetNumericId: initialFocusedAssetNumericId,
        initialScriptNumericId:
            assetsFilterScriptNumericId[0] ?? scriptList.first.numericId,
        onMutationStart: () => setDialogState(() => assetsBusy[0] = true),
        onMutationEnd: () {
          if (ctx.mounted) {
            setDialogState(() => assetsBusy[0] = false);
          }
        },
        reloadAssetsAndStats: reloadAssetsAndStats,
      );
    },
  );
}
