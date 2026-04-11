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
        Text('图片工作台', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: imageUrlCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '当前图片 URL / data URI',
            helperText: '支持 HTTP URL 或 data:image/...;base64。',
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
              child: Text(saving ? '处理中…' : '读取当前预览'),
            ),
            TextButton(
              onPressed: saving ? null : onSaveImageUrl,
              child: const Text('保存图片 URL'),
            ),
            TextButton(
              onPressed: saving ? null : onClearFrame,
              child: const Text('清空画面'),
            ),
            TextButton(
              onPressed: saving || loadingProduction
                  ? null
                  : onRefreshProductionData,
              child: Text(loadingProduction ? '刷新中…' : '刷新制作数据'),
            ),
          ],
        ),
      ],
    );
  }
}
