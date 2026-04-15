part of '../../home_page.dart';

/// Renders the current storyboard image preview and its production metadata.
class _StoryboardPreviewCard extends StatelessWidget {
  const _StoryboardPreviewCard({
    required this.loadingProduction,
    required this.productionRow,
    required this.metaLine,
  });

  final bool loadingProduction;
  final ProductionStoryboardItemV1? productionRow;
  final String metaLine;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final imageUrl = productionRow?.url?.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: outline.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前画面', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            metaLine,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 12),
          if (loadingProduction)
            const Center(child: CircularProgressIndicator())
          else if (imageUrl == null || imageUrl.isEmpty)
            Text(
              '当前分镜还没有选中的画面。可以先填写图片 URL，或先读取当前预览再继续生成视频。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: outline),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 180,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Text(
                    '图片预览失败\n$imageUrl',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          if ((productionRow?.prompt ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              productionRow!.prompt!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders the workbench diagnosis summary and the recommended next action.
class _StoryboardDiagnosisCard extends StatelessWidget {
  const _StoryboardDiagnosisCard({
    required this.diagnosis,
    required this.recommendedAction,
    required this.recommendedActionLabel,
  });

  final StoryboardWorkbenchDiagnosis diagnosis;
  final VoidCallback? recommendedAction;
  final String recommendedActionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diagnosis.summary,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            diagnosis.detail,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: recommendedAction,
            child: Text(recommendedActionLabel),
          ),
        ],
      ),
    );
  }
}
