part of 'view.dart';

/// Candidate comparison UI widget
class _CandidateComparePanel extends StatelessWidget {
  const _CandidateComparePanel({
    required this.candidateCardUi,
    required this.candidateComparePanelUi,
    required this.onOpenProjectsForCandidateAssets,
  });

  final ShortVideoCandidateCardUi candidateCardUi;
  final ShortVideoCandidateComparePanelUi candidateComparePanelUi;
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
                if (candidateCardUi.loading)
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: studioPanelMutedColor(context)),
                  )
                else if (candidateCardUi.unavailable)
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: studioPanelMutedColor(context)),
                  )
                else ...[
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: studioPanelMutedColor(context)),
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
                        OutlinedButton.icon(
                          style: studioFormOutlinedIconLabeledButtonStyle(
                            context,
                          ),
                          onPressed:
                              candidateCardUi.confirmStoryboardCandidatesBusy
                              ? null
                              : candidateCardUi.onConfirmStoryboardCandidates,
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
                      if (candidateCardUi.onBatchGenerateCandidateClips !=
                          null)
                        FilledButton.tonalIcon(
                          style: studioFormIconLabeledButtonStyle(context),
                          onPressed:
                              candidateCardUi.batchGenerateCandidateClipsBusy
                              ? null
                              : candidateCardUi.onBatchGenerateCandidateClips,
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
                  style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
                ),
                if (!candidateComparePanelUi.loading &&
                    !candidateComparePanelUi.unavailable) ...[
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
                                    child: _CandidateCompareCard(item: item),
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
                            childAspectRatio: 0.72,
                          ),
                          itemCount: candidateComparePanelUi.items.length,
                          itemBuilder: (context, index) {
                            return studioStaggeredItem(
                              index,
                              entranceKey: candidateComparePanelUi.items.length,
                              child: _CandidateCompareCard(
                                item: candidateComparePanelUi.items[index],
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
