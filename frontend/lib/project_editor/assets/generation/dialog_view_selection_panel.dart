part of 'dialog_view.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
    final outline = Theme.of(context).colorScheme.outline;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final scopeHint = filterScriptNumericId == null
        ? l10n.projectEditorAssetGenWorkbenchSelectionScopeGlobal
        : l10n.projectEditorAssetGenWorkbenchSelectionScopeFiltered(filterScriptNumericId!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          scopeHint,
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
                title: Text(l10n.l10nBatch_a242ae1254(asset.numericId, asset.name)),
                subtitle: Text(
                  [
                    asset.assetType,
                    asset.description?.trim().isNotEmpty == true
                        ? asset.description!.trim()
                        : l10n.projectEditorAssetGenWorkbenchAssetNoDescription,
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

