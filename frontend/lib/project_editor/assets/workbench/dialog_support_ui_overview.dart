part of 'dialog_support.dart';

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
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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

