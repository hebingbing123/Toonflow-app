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
    final l10n = resolveAppLocalizationsForErrors(context);
    final imageUrl = productionRow?.url?.trim();
    final narrationSource = describeStoryboardNarrationSource(
      l10n,
      resolveStoryboardNarrationSource(
        scriptStoryboard: scriptStoryboard,
        productionStoryboard: productionRow,
      ),
    );
    final voiceoverState = (productionRow?.voiceoverState ?? '').trim();
    final voiceoverAudioUrl = (productionRow?.voiceoverAudioUrl ?? '').trim();
    final voiceoverError = (productionRow?.voiceoverError ?? '').trim();
    final audioDeliveryLine = switch (voiceoverState) {
      'completed' when voiceoverAudioUrl.isNotEmpty =>
        l10n.scriptEditorStoryboardsVoiceoverCompleted,
      'queued' => l10n.scriptEditorStoryboardsVoiceoverQueued,
      'failed' when voiceoverError.isNotEmpty =>
        l10n.scriptEditorStoryboardsVoiceoverFailedWithError(voiceoverError),
      'failed' => l10n.scriptEditorStoryboardsVoiceoverFailed,
      _ => narrationSource,
    };
    return Container(
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: studioInsetPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.scriptEditorStoryboardsCurrentFrame,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            metaLine,
            style: studioHintStyle(context),
          ),
          const SizedBox(height: StudioSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final previewHeight = studioAspectHeightFromWidth(
                constraints.maxWidth.isFinite && constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width,
                min: 140,
                max: 240,
              );
              if (loadingProduction) {
                return SizedBox(
                  height: previewHeight,
                  child: const StudioMediaTileSkeleton(),
                );
              }
              if (imageUrl == null || imageUrl.isEmpty) {
                return Text(
                  l10n.scriptEditorStoryboardsNoSelectedFrame,
                  style: studioHintStyle(context),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
                child: StudioNetworkImage(
                  url: imageUrl,
                  height: previewHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: previewHeight,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Text(
                      l10n.scriptEditorStoryboardsPreviewLoadFailed(imageUrl),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              );
            },
          ),
          if ((productionRow?.prompt ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: StudioSpacing.sm),
            Text(
              productionRow!.prompt!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if ((productionRow?.videoDesc ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.scriptEditorStoryboardsSubtitleNarration(
                productionRow!.videoDesc!.trim(),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: studioHintStyle(context),
            ),
          ],
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.scriptEditorStoryboardsAudioDelivery(audioDeliveryLine),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: studioHintStyle(context),
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

  static List<({String label, bool ok})> _steps(
    AppLocalizations l10n,
    StoryboardShortVideoReadiness r,
  ) {
    return <({String label, bool ok})>[
      (label: l10n.scriptEditorStoryboardsReadinessBasicSlot, ok: r.hasBasicSlot),
      (
        label: l10n.scriptEditorStoryboardsReadinessPromptContext,
        ok: r.hasPromptContext,
      ),
      (
        label: l10n.scriptEditorStoryboardsReadinessReferenceVisual,
        ok: r.hasReferenceVisual,
      ),
      (
        label: l10n.scriptEditorStoryboardsReadinessCandidateCleared,
        ok: r.candidateCleared,
      ),
      (
        label: l10n.scriptEditorStoryboardsReadinessNoBlockingJob,
        ok: r.noBlockingJob,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final steps = _steps(l10n, readiness);
    final ready = readiness.readyForGeneration;
    final badgeStyle = theme.textTheme.labelMedium?.copyWith(
      color: ready ? theme.colorScheme.primary : studioPanelMutedColor(context),
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: studioInsetPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.scriptEditorStoryboardsReadinessTitle,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(
                ready
                    ? l10n.scriptEditorStoryboardsReadinessReady
                    : l10n.scriptEditorStoryboardsReadinessIncomplete,
                style: badgeStyle,
              ),
            ],
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          Wrap(
            spacing: StudioSpacing.xs,
            runSpacing: StudioSpacing.xs,
            children: [
              for (final step in steps)
                _ReadinessStepPill(
                  label: step.label,
                  ok: step.ok,
                ),
            ],
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          Text(
            formatStoryboardShortVideoReadinessSummaryLocalized(l10n, readiness),
            style: theme.textTheme.bodySmall?.copyWith(
              color: ready
                  ? theme.colorScheme.primary
                  : studioPanelMutedColor(context),
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
    final muted = studioPanelMutedColor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.highlight_off_outlined,
          size: 17,
          color: ok ? scheme.primary : muted,
        ),
        const SizedBox(width: StudioSpacing.xs),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: ok ? scheme.onSurface : muted,
          ),
        ),
      ],
    );
  }
}
