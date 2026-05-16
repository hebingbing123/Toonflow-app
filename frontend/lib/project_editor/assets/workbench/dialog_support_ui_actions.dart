part of 'dialog_support.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
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
              child: Text(l10n.projectEditorAssetsWorkbenchNewAsset),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onEdit : null,
              child: Text(l10n.projectEditorAssetsWorkbenchEditAsset),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onDelete : null,
              child: Text(l10n.projectEditorAssetsWorkbenchDeleteAsset),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onFilter : null,
              child: Text(l10n.projectEditorAssetsWorkbenchFilterAssets),
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
              child: Text(l10n.projectEditorAssetsWorkbenchLinkScript),
            ),
            OutlinedButton(
              onPressed: canLinkScripts ? onUnlink : null,
              child: Text(l10n.projectEditorAssetsWorkbenchUnlink),
            ),
            OutlinedButton(
              onPressed: canUploadEditImage ? onUploadEditImage : null,
              child: Text(l10n.projectEditorAssetsWorkbenchUploadEditImage),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onUploadClip,
              child: Text(l10n.projectEditorAssetsWorkbenchUploadClipAsset),
            ),
          ],
        ),
      ],
    );
  }
}
