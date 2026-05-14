part of 'dialog_support.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.projectEditorAssetsSpecializedWorkbenchesTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          l10n.projectEditorAssetsSpecializedWorkbenchesSubtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onOpenImagesWorkbench,
              child: Text(l10n.projectEditorAssetImagesWorkbenchDialogTitle),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onOpenGenerationWorkbench,
              child: Text(l10n.projectEditorAssetGenerationTitle),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onOpenHistoryWorkbench,
              child: Text(l10n.projectEditorAssetHistoryTitle),
            ),
          ],
        ),
      ],
    );
  }
}

