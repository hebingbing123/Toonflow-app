part of '../../../home_page.dart';

/// Presents the asset-workbench summary and current focus selectors so the
/// assets dialog can stay centered on orchestration.
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
              Text(scriptScopedLine, style: Theme.of(context).textTheme.bodySmall),
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
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('（当前无资产）'),
            ),
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
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('（当前无剧本）'),
            ),
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

/// Groups the primary asset actions and related child workbench launchers used
/// inside the assets workbench dialog.
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
              onPressed:
                  localBusy || assetsBusy ? null : onOpenGenerationWorkbench,
              child: const Text('资产出图工作台'),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onOpenHistoryWorkbench,
              child: const Text('资产历史图工作台'),
            ),
          ],
        ),
      ],
    );
  }
}
