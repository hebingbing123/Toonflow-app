part of '../../../../home_page.dart';

/// Renders the scoped asset selection help text and checkbox list.
class _AssetGenerationSelectionPanel extends StatelessWidget {
  const _AssetGenerationSelectionPanel({
    required this.busy,
    required this.filterScriptNumericId,
    required this.scopedAssets,
    required this.selectedIds,
    required this.onToggleAsset,
  });

  final bool busy;
  final int? filterScriptNumericId;
  final List<AssetRow> scopedAssets;
  final Set<int> selectedIds;
  final void Function(AssetRow asset, bool checked) onToggleAsset;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filterScriptNumericId == null
              ? '当前按项目全量资产操作；可在主视图先切换"按剧本筛选"再进入工作台。'
              : '当前主视图已按剧本 #$filterScriptNumericId 过滤资产，工作台默认沿用这批可见资产。',
          style: bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.builder(
            itemCount: scopedAssets.length,
            itemBuilder: (context, index) {
              final asset = scopedAssets[index];
              return CheckboxListTile(
                dense: true,
                value: selectedIds.contains(asset.numericId),
                onChanged: busy
                    ? null
                    : (checked) => onToggleAsset(asset, checked == true),
                title: Text('#${asset.numericId} ${asset.name}'),
                subtitle: Text(
                  [
                    asset.assetType,
                    asset.description?.trim().isNotEmpty == true
                        ? asset.description!.trim()
                        : '无描述',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }
}
