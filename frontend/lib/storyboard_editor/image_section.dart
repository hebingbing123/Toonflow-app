part of '../../home_page.dart';

/// Renders the image-side controls for the storyboard workbench.
class _StoryboardImageSection extends StatelessWidget {
  const _StoryboardImageSection({
    required this.saving,
    required this.loadingProduction,
    required this.imageUrlCtrl,
    required this.onReadCurrentPreview,
    required this.onSaveImageUrl,
    required this.onClearFrame,
    required this.onRefreshProductionData,
  });

  final bool saving;
  final bool loadingProduction;
  final TextEditingController imageUrlCtrl;
  final VoidCallback onReadCurrentPreview;
  final VoidCallback onSaveImageUrl;
  final VoidCallback onClearFrame;
  final VoidCallback onRefreshProductionData;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectEditorStoryboardImageWorkbenchTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: imageUrlCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.projectEditorStoryboardImageUrlLabel,
            helperText: l10n.projectEditorStoryboardImageUrlHelper,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: saving ? null : onReadCurrentPreview,
              child: Text(
                saving
                    ? l10n.projectEditorStoryboardImageWorking
                    : l10n.projectEditorStoryboardImageLoadPreview,
              ),
            ),
            TextButton(
              onPressed: saving ? null : onSaveImageUrl,
              child: Text(l10n.projectEditorStoryboardImageSaveUrl),
            ),
            TextButton(
              onPressed: saving ? null : onClearFrame,
              child: Text(l10n.projectEditorStoryboardImageClearFrame),
            ),
            TextButton(
              onPressed: saving || loadingProduction
                  ? null
                  : onRefreshProductionData,
              child: Text(
                loadingProduction
                    ? l10n.projectEditorStoryboardImageRefreshing
                    : l10n.projectEditorStoryboardImageRefreshProduction,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
