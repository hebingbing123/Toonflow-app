import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/ix/studio_mobile_affordances.dart';
import '../../rust_api.dart';
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
              unawaited(studioLightImpact());
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
          style: studioHintStyle(ctx),
        ),
    ],
  );
}
