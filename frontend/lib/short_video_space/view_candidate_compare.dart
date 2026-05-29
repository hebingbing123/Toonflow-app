part of 'view.dart';

/// Candidate comparison UI widget (also used in responsive master pane).
class ShortVideoCandidateCompareSection extends StatelessWidget {
  const ShortVideoCandidateCompareSection({
    super.key,
    required this.accessToken,
    required this.candidateCardUi,
    required this.candidateComparePanelUi,
    required this.videoRatio,
    this.onOpenProjectsForCandidateAssets,
  });

  final String? accessToken;
  final ShortVideoCandidateCardUi candidateCardUi;
  final ShortVideoCandidateComparePanelUi candidateComparePanelUi;
  final String videoRatio;
  final VoidCallback? onOpenProjectsForCandidateAssets;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (candidateCardUi.visible) ...[
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortVideoCandidateAssetConfirmationTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                _ShortVideoPanelFetchBody(
                  loading: candidateCardUi.loading,
                  unavailable: candidateCardUi.unavailable,
                  statusLine: candidateCardUi.headline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidateCardUi.headline,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: studioPanelMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: StudioLayoutSpacing.inlineGap),
                      Wrap(
                        spacing: StudioSpacing.xs,
                        runSpacing: StudioSpacing.xs,
                        children: [
                          _MetricChip(
                            label: l10n.shortVideoCandidateMetricPending,
                            value: '${candidateCardUi.pending}',
                          ),
                          _MetricChip(
                            label: l10n.shortVideoCandidateMetricLinked,
                            value: '${candidateCardUi.linked}',
                          ),
                          _MetricChip(
                            label: l10n.shortVideoCandidateMetricIgnored,
                            value: '${candidateCardUi.ignored}',
                          ),
                          _MetricChip(
                            label: l10n.shortVideoCandidateMetricUnset,
                            value: '${candidateCardUi.unset}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  candidateCardUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
                ),
                if (candidateCardUi.onConfirmStoryboardCandidates != null ||
                    candidateCardUi.onBatchGenerateCandidateClips != null ||
                    onOpenProjectsForCandidateAssets != null) ...[
                  const SizedBox(height: StudioLayoutSpacing.inlineGap),
                  StudioDenseActionRow(
                    children: <Widget>[
                      if (candidateCardUi.onConfirmStoryboardCandidates != null)
                        StudioDebouncedAction(
                          enabled: !candidateCardUi.confirmStoryboardCandidatesBusy,
                          onPressed: candidateCardUi.confirmStoryboardCandidatesBusy
                              ? null
                              : () async {
                                  candidateCardUi.onConfirmStoryboardCandidates!();
                                },
                          builder: (context, onPressed) => OutlinedButton.icon(
                            style: studioFormOutlinedIconLabeledButtonStyle(
                              context,
                            ),
                            onPressed: onPressed,
                            icon: candidateCardUi.confirmStoryboardCandidatesBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(l10n.globalSearchConfirm),
                          ),
                        ),
                      if (candidateCardUi.onBatchGenerateCandidateClips != null)
                        StudioDebouncedAction(
                          enabled: !candidateCardUi.batchGenerateCandidateClipsBusy,
                          onPressed: candidateCardUi.batchGenerateCandidateClipsBusy
                              ? null
                              : () async {
                                  candidateCardUi.onBatchGenerateCandidateClips!();
                                },
                          builder: (context, onPressed) => FilledButton.tonalIcon(
                            style: studioFormIconLabeledButtonStyle(context),
                            onPressed: onPressed,
                            icon: candidateCardUi.batchGenerateCandidateClipsBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.movie_creation_outlined),
                            label: Text(
                              candidateCardUi.batchGenerateCandidateClipsBusy
                                  ? l10n.shortVideoCandidateBatchGenerateSubmitting
                                  : l10n.shortVideoCandidateBatchGenerateLabel,
                            ),
                          ),
                        ),
                      if (onOpenProjectsForCandidateAssets != null)
                        OutlinedButton.icon(
                          style: studioFormOutlinedIconLabeledButtonStyle(
                            context,
                          ),
                          onPressed: onOpenProjectsForCandidateAssets,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: Text(
                            l10n.shortVideoCandidateOpenProjectsForAssets,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: StudioSpacing.sm),
        ],
        if (candidateComparePanelUi.visible) ...[
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortVideoCandidateCompareSectionTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  candidateComparePanelUi.headline,
                  style: theme.textTheme.bodyMedium?.copyWith(color: studioPanelMutedColor(context)),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  candidateComparePanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: studioPanelMutedColor(context),
                  ),
                ),
                if (candidateComparePanelUi.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: StudioSpacing.sm),
                    child: StudioListSkeleton(itemCount: 2),
                  )
                else if (!candidateComparePanelUi.unavailable) ...[
                  const SizedBox(height: StudioSpacing.sm),
                  if (candidateComparePanelUi.items.isEmpty)
                    StudioEmptyState.emptyData(
                      title: candidateComparePanelUi.headline,
                      subtitle: candidateComparePanelUi.detail,
                      icon: Icons.compare_outlined,
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = studioGridCrossAxisCount(
                          constraints.maxWidth,
                          handset: 1,
                          tablet: 2,
                          desktop: 3,
                          desktopWide: 4,
                          desktopWideMin: 1440,
                        );
                        if (crossAxisCount <= 1) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: candidateComparePanelUi.items
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: StudioSpacing.radiusComfort,
                                    ),
                                    child: _CandidateCompareCard(
                                      accessToken: accessToken,
                                      item: item,
                                      videoRatio: videoRatio,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        }
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: StudioSpacing.radiusComfort,
                            crossAxisSpacing: StudioSpacing.radiusComfort,
                            childAspectRatio: shortVideoAspectRatioFromLabel(
                              videoRatio,
                            ),
                          ),
                          itemCount: candidateComparePanelUi.items.length,
                          itemBuilder: (context, index) {
                            return studioStaggeredItem(
                              index,
                              entranceKey: candidateComparePanelUi.items.length,
                              child: _CandidateCompareCard(
                                accessToken: accessToken,
                                item: candidateComparePanelUi.items[index],
                                videoRatio: videoRatio,
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CandidateCompareCard extends StatelessWidget {
  const _CandidateCompareCard({
    required this.accessToken,
    required this.item,
    required this.videoRatio,
  });

  final String? accessToken;
  final ShortVideoCandidateCompareItemUi item;
  final String videoRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final header = item.scriptNumericId != null
        ? l10n.shortVideoCandidateCompareStoryboardWithScript(
            item.storyboardNumericId,
            item.scriptNumericId!,
          )
        : l10n.shortVideoCandidateCompareStoryboardOnly(
            item.storyboardNumericId,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : studioWrapTileWidth(
                MediaQuery.sizeOf(context).width,
                maxColumns: 1,
                minTileWidth: 260,
                maxTileWidth: double.infinity,
              );
        final previewHeight = studioPreviewImageHeight(
          280,
          fraction: 0.45,
          min: 120,
          max: 200,
        );
        return SizedBox(
          width: cardWidth,
          child: Container(
        padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
        decoration: BoxDecoration(
          color: tokens.bgSurface.withValues(alpha: 0.96),
          border: Border.all(color: tokens.borderSubtle),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(header, style: studioCardTitleStyle(context)),
            const SizedBox(height: StudioSpacing.xs),
            Text(item.readinessLine, style: theme.textTheme.bodySmall),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              item.qualityLine,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            if ((item.writebackLine ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: StudioSpacing.xs),
              _WritebackStatusChip(
                line: item.writebackLine!,
                indicatesProblem: item.writebackIndicatesProblem,
              ),
            ],
            if ((item.referenceImageUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              StudioHero(
                tag: 'short_video_candidate_${item.storyboardNumericId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                  child: StudioNetworkImage(
                    accessToken: accessToken,
                    url: item.referenceImageUrl!,
                    height: previewHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: previewHeight,
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Text(
                        l10n.shortVideoCandidateReferenceImageNotPreviewable,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (item.liveActionReferenceShotUrls.isNotEmpty) ...[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.shortVideoCandidateLiveRefShotCount(
                  item.liveActionReferenceShotUrls.length,
                ),
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                item.liveActionReferenceShotUrls.take(2).join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            if ((item.selectedVideoUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.shortVideoCandidateCurrentVideo,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: StudioSpacing.xs),
              SelectableText(
                item.selectedVideoUrl!,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: StudioSpacing.xs),
              OutlinedButton.icon(
                style: studioFormOutlinedIconLabeledButtonStyle(context),
                onPressed: () {
                  unawaited(
                    PreviewPlayerDialog.show(
                      context,
                      videoUrl: item.selectedVideoUrl!,
                      shotNumber: item.storyboardNumericId,
                      videoRatio: videoRatio,
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: StudioIconSize.sm),
                label: Text(l10n.shortVideoTimelinePlayPreview),
              ),
            ],
            if (item.candidateVideoUrls.isNotEmpty) ...[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.shortVideoCandidateVideoListTitle,
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: StudioSpacing.xs),
              ...studioStaggeredChildren(
                item.candidateVideoUrls.map((url) {
                  final isCurrent =
                      url.trim() == (item.selectedVideoUrl ?? '').trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SelectableText(
                            url,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isCurrent ? theme.colorScheme.primary : null,
                            ),
                          ),
                        ),
                        if (item.onSelectCandidateVideo != null && !isCurrent)
                          StudioDebouncedAction(
                            onPressed: () async =>
                                item.onSelectCandidateVideo!(url),
                            builder: (context, onPressed) => TextButton(
                              onPressed: onPressed,
                              child: Text(l10n.shortVideoCandidateSelectVideo),
                            ),
                          ),
                        StudioUtilityIconButton(
                          icon: Icons.play_arrow_outlined,
                          label: l10n.shortVideoTimelinePlayPreview,
                          onPressed: () {
                            unawaited(
                              PreviewPlayerDialog.show(
                                context,
                                videoUrl: url,
                                shotNumber: item.storyboardNumericId,
                                videoRatio: videoRatio,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }),
                entranceKey: item.candidateVideoUrls.length,
              ),
            ],
            const SizedBox(height: StudioSpacing.xs),
            StudioDenseActionRow(
              spacing: StudioSpacing.xs,
              children: [
                if (item.onSetCurrent != null)
                  StudioDebouncedAction(
                    onPressed: () async => item.onSetCurrent!(),
                    builder: (context, onPressed) => FilledButton.tonal(
                      style: studioFormTonalButtonStyle(context),
                      onPressed: onPressed,
                      child: Text(l10n.shortVideoCandidateSetCurrent),
                    ),
                  ),
                if (item.onOpenRework != null)
                  StudioDebouncedAction(
                    onPressed: () async => item.onOpenRework!(),
                    builder: (context, onPressed) => OutlinedButton(
                      style: studioFormSecondaryButtonStyle(context),
                      onPressed: onPressed,
                      child: Text(l10n.shortVideoCandidatePartialRework),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
        );
      },
    );
  }
}
