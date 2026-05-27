part of 'dialog_support.dart';

class _ProjectAssetsWorkbenchOverview extends StatelessWidget {
  const _ProjectAssetsWorkbenchOverview({
    this.focusNotice,
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

  final String? focusNotice;
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (focusNotice != null) ...[
          Text(
            focusNotice!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
          decoration: studioInsetPanelDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(statusLine, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                scriptScopedLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (selectedAsset != null) ...[
                const SizedBox(height: StudioSpacing.xs),
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
        const SizedBox(height: StudioSpacing.sm),
        StudioDropdownButtonFormField<int?>(
          initialValue: selectedAssetNumericId,
          decoration: InputDecoration(
            labelText: l10n.projectEditorAssetsWorkbenchFocusAssetLabel,
            helperText: l10n.projectEditorAssetsWorkbenchFocusAssetHelper,
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                l10n.projectEditorAssetsWorkbenchFocusAssetEmptyOption,
              ),
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
        const SizedBox(height: StudioSpacing.xs),
        StudioDropdownButtonFormField<int?>(
          initialValue: selectedScriptNumericId,
          decoration: InputDecoration(
            labelText: l10n.projectEditorAssetsWorkbenchFocusScriptLabel,
            helperText: l10n.projectEditorAssetsWorkbenchFocusScriptHelper,
          ),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                l10n.projectEditorAssetsWorkbenchFocusScriptEmptyOption,
              ),
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
