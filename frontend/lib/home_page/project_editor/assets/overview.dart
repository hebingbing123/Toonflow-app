part of '../../../home_page.dart';

/// Renders the assets overview, script filter, and workbench entry actions.
class _ProjectAssetsOverviewPanel extends StatelessWidget {
  const _ProjectAssetsOverviewPanel({
    required this.scriptList,
    required this.visibleAssets,
    required this.assetsForScript,
    required this.filterScriptNumericId,
    required this.assetsLoading,
    required this.assetsScriptFilterLoading,
    required this.assetsBusy,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onOpenWorkbench,
  });

  final List<ScriptBrief> scriptList;
  final List<AssetRow> visibleAssets;
  final List<AssetRow>? assetsForScript;
  final int? filterScriptNumericId;
  final bool assetsLoading;
  final bool assetsScriptFilterLoading;
  final bool assetsBusy;
  final ValueChanged<int?> onFilterChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenWorkbench;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodySmall = theme.textTheme.bodySmall;
    final outline = theme.colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summarizeProjectAssetRows(visibleAssets), style: bodySmall),
        if (filterScriptNumericId != null) ...[
          const SizedBox(height: 6),
          if (assetsScriptFilterLoading)
            Text(
              '正在按剧本筛选资产…',
              style: bodySmall?.copyWith(color: outline),
            )
          else if (assetsForScript != null)
            Text(
              summarizeScriptScopedAssets(filterScriptNumericId, assetsForScript!),
              style: bodySmall,
            )
          else
            Text(
              '当前剧本资产尚未加载',
              style: bodySmall?.copyWith(color: outline),
            ),
        ],
        if (scriptList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButton<int?>(
              value: filterScriptNumericId,
              isExpanded: true,
              hint: const Text('按剧本筛选资产列表'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('（全部，不按剧本筛选）'),
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
              onChanged:
                  assetsBusy || assetsLoading || assetsScriptFilterLoading
                  ? null
                  : (value) => onFilterChanged(value),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: assetsLoading || assetsScriptFilterLoading
                ? null
                : () => onRefresh(),
            child: Text(assetsLoading ? '刷新资产…' : '刷新资产'),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('资产主工作台', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '把资产 CRUD、剧本关联、筛选与上传动作收口到一个正式入口，主区不再堆叠一排零散按钮。',
                style: bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed:
                    assetsBusy || assetsLoading || assetsScriptFilterLoading
                    ? null
                    : onOpenWorkbench,
                child: const Text('打开资产主工作台'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
