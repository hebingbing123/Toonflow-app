import 'package:flutter/material.dart';

import '../../rust_api.dart';
import 'compatibility/panel.dart';
import 'overview.dart';

Widget buildProjectAssetsSection({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<ScriptBrief> scriptList,
  required List<ListAssetsResponse?> assetsRef,
  required List<ListAssetsResponse?> assetsForScriptRef,
  required List<int?> assetsFilterScriptNumericId,
  required List<String?> assetsFocusNoticeRef,
  required List<bool> assetsLoading,
  required List<bool> assetsScriptFilterLoading,
  required List<bool> assetsBusy,
  required Future<void> Function() reloadAssetsAndStats,
  required Future<void> Function() openWorkbench,
  required Widget Function() buildImagesSection,
  required List<Widget> Function() buildPrimaryActions,
  required List<Widget> Function() buildRelationActions,
  required List<Widget> Function() buildQueryActions,
}) {
  final l10n = resolveAppLocalizationsForErrors(ctx);
  final visibleAssets = assetsRef[0]?.items ?? const <AssetRow>[];
  final assetsForScript = assetsForScriptRef[0]?.items;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (assetsRef[0] != null)
        ProjectAssetsOverviewView(
          model: ProjectAssetsOverviewViewModel(
            scriptList: scriptList,
            visibleAssets: visibleAssets,
            assetsForScript: assetsForScript,
            filterScriptNumericId: assetsFilterScriptNumericId[0],
            focusNotice: assetsFocusNoticeRef[0],
            assetsLoading: assetsLoading[0],
            assetsScriptFilterLoading: assetsScriptFilterLoading[0],
            assetsBusy: assetsBusy[0],
          ),
          callbacks: ProjectAssetsOverviewViewCallbacks(
            onFilterChanged: (value) async {
              setDialogState(() => assetsScriptFilterLoading[0] = true);
              assetsFilterScriptNumericId[0] = value;
              assetsFocusNoticeRef[0] = null;
              if (value == null) {
                assetsForScriptRef[0] = null;
              }
              try {
                await reloadAssetsAndStats();
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => assetsScriptFilterLoading[0] = false);
                }
              }
            },
            onRefresh: () async {
              setDialogState(() => assetsLoading[0] = true);
              try {
                await reloadAssetsAndStats();
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => assetsLoading[0] = false);
                }
              }
            },
            onOpenWorkbench: () => openWorkbench(),
          ),
        )
      else
        Text(
          l10n.projectEditorAssetsSectionListNotLoaded,
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
      const SizedBox(height: 8),
      ProjectAssetsCompatibilityPanel(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        project: project,
        scriptList: scriptList,
        assetsRef: assetsRef,
        assetsFilterScriptNumericId: assetsFilterScriptNumericId,
        assetsLoading: assetsLoading,
        assetsScriptFilterLoading: assetsScriptFilterLoading,
        assetsBusy: assetsBusy,
        reloadAssetsAndStats: reloadAssetsAndStats,
        buildImagesSection: buildImagesSection,
        buildPrimaryActions: buildPrimaryActions,
        buildRelationActions: buildRelationActions,
        buildQueryActions: buildQueryActions,
      ),
    ],
  );
}
