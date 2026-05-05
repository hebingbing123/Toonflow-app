part of '../../home_page.dart';

/// Renders the current storyboard image preview and its production metadata.
class _StoryboardPreviewCard extends StatelessWidget {
  const _StoryboardPreviewCard({
    required this.loadingProduction,
    required this.scriptStoryboard,
    required this.productionRow,
    required this.metaLine,
  });

  final bool loadingProduction;
  final StoryboardRow scriptStoryboard;
  final ProductionStoryboardItemV1? productionRow;
  final String metaLine;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final imageUrl = productionRow?.url?.trim();
    final narrationSource = describeStoryboardNarrationSource(
      resolveStoryboardNarrationSource(
        scriptStoryboard: scriptStoryboard,
        productionStoryboard: productionRow,
      ),
    );
    final voiceoverState = (productionRow?.voiceoverState ?? '').trim();
    final voiceoverAudioUrl = (productionRow?.voiceoverAudioUrl ?? '').trim();
    final voiceoverError = (productionRow?.voiceoverError ?? '').trim();
    final audioDeliveryLine = switch (voiceoverState) {
      'completed' when voiceoverAudioUrl.isNotEmpty => '已生成配音',
      'queued' => '配音排队中',
      'failed' when voiceoverError.isNotEmpty => '配音失败：$voiceoverError',
      'failed' => '配音失败',
      _ => narrationSource,
    };
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
          if ((productionRow?.videoDesc ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '字幕/旁白：${productionRow!.videoDesc!.trim()}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '音频交付：$audioDeliveryLine',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
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
          Text(diagnosis.detail, style: Theme.of(context).textTheme.bodySmall),
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

/// Read-only checklist aligned with **`GET …/short-video-readiness`** (C11 / MP-W3).
class _StoryboardShortVideoReadinessStrip extends StatelessWidget {
  const _StoryboardShortVideoReadinessStrip({required this.readiness});

  final StoryboardShortVideoReadiness readiness;

  static List<({String label, bool ok})> _steps(StoryboardShortVideoReadiness r) {
    return <({String label, bool ok})>[
      (label: '时间线槽位', ok: r.hasBasicSlot),
      (label: '脚本 / 提示词', ok: r.hasPromptContext),
      (label: '参考图', ok: r.hasReferenceVisual),
      (label: '候选确认', ok: r.candidateCleared),
      (label: '无阻塞任务', ok: r.noBlockingJob),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final steps = _steps(readiness);
    final ready = readiness.readyForGeneration;
    final badgeStyle = theme.textTheme.labelMedium?.copyWith(
      color: ready ? theme.colorScheme.primary : outline,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: outline.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '短视频就绪（服务端）',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(
                ready ? '可生成' : '待补齐',
                style: badgeStyle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final step in steps)
                _ReadinessStepPill(
                  label: step.label,
                  ok: step.ok,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatStoryboardShortVideoReadinessSummary(readiness),
            style: theme.textTheme.bodySmall?.copyWith(
              color: ready ? theme.colorScheme.primary : outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessStepPill extends StatelessWidget {
  const _ReadinessStepPill({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final outline = scheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.highlight_off_outlined,
          size: 17,
          color: ok ? scheme.primary : outline,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: ok ? scheme.onSurface : outline,
          ),
        ),
      ],
    );
  }
}
