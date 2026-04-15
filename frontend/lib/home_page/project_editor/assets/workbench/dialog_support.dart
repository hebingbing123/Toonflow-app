import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import '../support.dart';

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

AlertDialog buildProjectAssetsWorkbenchDialog({
  required BuildContext dialogCtx,
  required bool localBusy,
  required bool assetsBusy,
  required String statusLine,
  required List<AssetRow> scopedAssets,
  required int? assetsFilterScriptNumericId,
  required AssetRow? selectedAsset,
  required List<AssetRow> assets,
  required List<ScriptBrief> scriptList,
  required int? selectedAssetNumericId,
  required int? selectedScriptNumericId,
  required ValueChanged<int?>? onAssetChanged,
  required ValueChanged<int?>? onScriptChanged,
  required Future<void> Function() onCreate,
  required Future<void> Function() onEdit,
  required Future<void> Function() onDelete,
  required Future<void> Function() onFilter,
  required Future<void> Function() onLink,
  required Future<void> Function() onUnlink,
  required Future<void> Function() onUploadEditImage,
  required Future<void> Function() onUploadClip,
  required Future<void> Function() onOpenImagesWorkbench,
  required Future<void> Function() onOpenGenerationWorkbench,
  required Future<void> Function() onOpenHistoryWorkbench,
  required VoidCallback? onRefresh,
  required VoidCallback? onClose,
}) {
  return AlertDialog(
    title: const Text('资产主工作台'),
    content: SizedBox(
      width: 780,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '把资产 CRUD、剧本关联、筛选和上传入口收口到一个正式工作台，主区不再堆一排控制台式按钮。',
              style: Theme.of(dialogCtx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _ProjectAssetsWorkbenchOverview(
              statusLine: statusLine,
              scriptScopedLine: summarizeScriptScopedAssets(
                assetsFilterScriptNumericId,
                scopedAssets,
              ),
              selectedAsset: selectedAsset,
              assets: assets,
              scriptList: scriptList,
              selectedAssetNumericId: selectedAssetNumericId,
              selectedScriptNumericId: selectedScriptNumericId,
              onAssetChanged: onAssetChanged,
              onScriptChanged: onScriptChanged,
            ),
            const SizedBox(height: 12),
            _ProjectAssetsWorkbenchActions(
              localBusy: localBusy,
              assetsBusy: assetsBusy,
              assets: assets,
              scriptList: scriptList,
              selectedScriptNumericId: selectedScriptNumericId,
              onCreate: onCreate,
              onEdit: onEdit,
              onDelete: onDelete,
              onFilter: onFilter,
              onLink: onLink,
              onUnlink: onUnlink,
              onUploadEditImage: onUploadEditImage,
              onUploadClip: onUploadClip,
            ),
            const SizedBox(height: 12),
            _ProjectAssetsWorkbenchLaunchers(
              localBusy: localBusy,
              assetsBusy: assetsBusy,
              onOpenImagesWorkbench: onOpenImagesWorkbench,
              onOpenGenerationWorkbench: onOpenGenerationWorkbench,
              onOpenHistoryWorkbench: onOpenHistoryWorkbench,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: onRefresh,
        child: Text(localBusy ? '处理中…' : '刷新工作台'),
      ),
      TextButton(onPressed: onClose, child: const Text('关闭')),
    ],
  );
}

class _ProjectAssetsWorkbenchOverview extends StatelessWidget {
  const _ProjectAssetsWorkbenchOverview({
    required this.statusLine,
    required this.scriptScopedLine,
    required this.selectedAsset,
    required this.assets,
    required this.scriptList,
    required this.selectedAssetNumericId,
    required this.selectedScriptNumericId,
    required this.onAssetChanged,
    required this.onScriptChanged,
  });

  final String statusLine;
  final String scriptScopedLine;
  final AssetRow? selectedAsset;
  final List<AssetRow> assets;
  final List<ScriptBrief> scriptList;
  final int? selectedAssetNumericId;
  final int? selectedScriptNumericId;
  final ValueChanged<int?>? onAssetChanged;
  final ValueChanged<int?>? onScriptChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusLine, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                scriptScopedLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (selectedAsset != null) ...[
                const SizedBox(height: 6),
                Text(
                  '当前焦点资产：#${selectedAsset!.numericId} ${selectedAsset!.name} · ${selectedAsset!.assetType}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          initialValue: selectedAssetNumericId,
          decoration: const InputDecoration(
            labelText: '当前焦点资产',
            helperText: '用于快速查看当前工作焦点；具体编辑在下方动作中完成。',
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('（当前无资产）')),
            ...assets.map(
              (asset) => DropdownMenuItem<int?>(
                value: asset.numericId,
                child: Text(
                  '#${asset.numericId} ${asset.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onAssetChanged,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          initialValue: selectedScriptNumericId,
          decoration: const InputDecoration(
            labelText: '当前焦点剧本',
            helperText: '用于剧本-资产关联相关动作。',
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('（当前无剧本）')),
            ...scriptList.map(
              (script) => DropdownMenuItem<int?>(
                value: script.numericId,
                child: Text(
                  '#${script.numericId} ${script.name ?? ""}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onScriptChanged,
        ),
      ],
    );
  }
}

class _ProjectAssetsWorkbenchActions extends StatelessWidget {
  const _ProjectAssetsWorkbenchActions({
    required this.localBusy,
    required this.assetsBusy,
    required this.assets,
    required this.scriptList,
    required this.selectedScriptNumericId,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onFilter,
    required this.onLink,
    required this.onUnlink,
    required this.onUploadEditImage,
    required this.onUploadClip,
  });

  final bool localBusy;
  final bool assetsBusy;
  final List<AssetRow> assets;
  final List<ScriptBrief> scriptList;
  final int? selectedScriptNumericId;
  final VoidCallback onCreate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFilter;
  final VoidCallback onLink;
  final VoidCallback onUnlink;
  final VoidCallback onUploadEditImage;
  final VoidCallback onUploadClip;

  @override
  Widget build(BuildContext context) {
    final canMutateAssets = !(localBusy || assetsBusy || assets.isEmpty);
    final canLinkScripts =
        !(localBusy ||
            assetsBusy ||
            assets.isEmpty ||
            scriptList.isEmpty ||
            selectedScriptNumericId == null);
    final canUploadEditImage = !(localBusy || assetsBusy || scriptList.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: localBusy || assetsBusy ? null : onCreate,
              child: const Text('新建资产'),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onEdit : null,
              child: const Text('编辑资产'),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onDelete : null,
              child: const Text('删除资产'),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onFilter : null,
              child: const Text('筛选资产'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: canLinkScripts ? onLink : null,
              child: const Text('关联剧本与资产'),
            ),
            OutlinedButton(
              onPressed: canLinkScripts ? onUnlink : null,
              child: const Text('取消关联'),
            ),
            OutlinedButton(
              onPressed: canUploadEditImage ? onUploadEditImage : null,
              child: const Text('上传编辑图片'),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onUploadClip,
              child: const Text('上传 Clip 资产'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProjectAssetsWorkbenchLaunchers extends StatelessWidget {
  const _ProjectAssetsWorkbenchLaunchers({
    required this.localBusy,
    required this.assetsBusy,
    required this.onOpenImagesWorkbench,
    required this.onOpenGenerationWorkbench,
    required this.onOpenHistoryWorkbench,
  });

  final bool localBusy;
  final bool assetsBusy;
  final VoidCallback onOpenImagesWorkbench;
  final VoidCallback onOpenGenerationWorkbench;
  final VoidCallback onOpenHistoryWorkbench;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('专项工作台', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '把图片管理、出图链路和历史图查询也统一挂到这里，资产主区只保留一个正式入口。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onOpenImagesWorkbench,
              child: const Text('资产图片工作台'),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy
                  ? null
                  : onOpenGenerationWorkbench,
              child: const Text('资产出图工作台'),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy
                  ? null
                  : onOpenHistoryWorkbench,
              child: const Text('资产历史图工作台'),
            ),
          ],
        ),
      ],
    );
  }
}
