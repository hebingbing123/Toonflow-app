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
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.projectEditorAssetsWorkbenchFocusAssetSummary(
                    selectedAsset!.numericId,
                    selectedAsset!.name,
                    selectedAsset!.assetType,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          initialValue: selectedAssetNumericId,
          decoration: InputDecoration(
            labelText: l10n.projectEditorAssetsWorkbenchFocusAssetLabel,
            helperText: l10n.projectEditorAssetsWorkbenchFocusAssetHelper,
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(l10n.projectEditorAssetsWorkbenchFocusAssetEmptyOption),
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
          decoration: InputDecoration(
            labelText: l10n.projectEditorAssetsWorkbenchFocusScriptLabel,
            helperText: l10n.projectEditorAssetsWorkbenchFocusScriptHelper,
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(l10n.projectEditorAssetsWorkbenchFocusScriptEmptyOption),
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
