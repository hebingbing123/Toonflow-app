part of '../../../../home_page.dart';

AssetRow? findAssetByNumericId(List<AssetRow> assets, int? numericId) {
  if (numericId == null) {
    return null;
  }
  for (final row in assets) {
    if (row.numericId == numericId) {
      return row;
    }
  }
  return null;
}

Future<void> refreshProjectAssetsWorkbench({
  required Future<void> Function() reloadAssetsAndStats,
  required List<ListAssetsResponse?> assetsRef,
  required int? selectedAssetNumericId,
  required ValueChanged<int?> onSelectedAssetNumericIdChanged,
  required ValueChanged<String> onStatusLineChanged,
  required StateSetter setLocalState,
}) async {
  await reloadAssetsAndStats();
  final refreshed = assetsRef[0]?.items ?? const <AssetRow>[];
  setLocalState(() {
    onSelectedAssetNumericIdChanged(
      chooseInitialAssetNumericId(
        refreshed,
        preferredNumericId: selectedAssetNumericId,
      ),
    );
    onStatusLineChanged(
      refreshed.isEmpty
          ? '当前项目还没有资产，可直接在这里创建。'
          : summarizeProjectAssetRows(refreshed),
    );
  });
}

Future<void> runAction({
  required BuildContext ctx,
  required StateSetter setLocalState,
  required ValueChanged<bool> onBusyChanged,
  required Future<void> Function() refreshWorkbench,
  required Future<void> Function() action,
}) async {
  setLocalState(() => onBusyChanged(true));
  try {
    await action();
    if (ctx.mounted) {
      await refreshWorkbench();
    }
  } finally {
    if (ctx.mounted) {
      setLocalState(() => onBusyChanged(false));
    }
  }
}

Future<void> openChildWorkbench({
  required BuildContext parentCtx,
  required BuildContext dialogCtx,
  required Future<void> Function() refreshWorkbench,
  required Future<void> Function() action,
}) async {
  await action();
  if (!dialogCtx.mounted || !parentCtx.mounted) {
    return;
  }
  await refreshWorkbench();
}
