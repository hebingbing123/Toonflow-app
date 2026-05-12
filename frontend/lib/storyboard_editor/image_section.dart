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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Image workbench', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: imageUrlCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Current image URL / data URI',
            helperText: 'HTTP URL or data:image/...;base64.',
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
              child: Text(saving ? 'Working…' : 'Load current preview'),
            ),
            TextButton(
              onPressed: saving ? null : onSaveImageUrl,
              child: const Text('Save image URL'),
            ),
            TextButton(
              onPressed: saving ? null : onClearFrame,
              child: const Text('Clear frame'),
            ),
            TextButton(
              onPressed: saving || loadingProduction
                  ? null
                  : onRefreshProductionData,
              child: Text(
                loadingProduction ? 'Refreshing…' : 'Refresh production data',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
