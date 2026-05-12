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
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (candidateCardUi.visible) ...[
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Candidate asset confirmation',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (candidateCardUi.loading)
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (candidateCardUi.unavailable)
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    candidateCardUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricChip(
                        label: 'Pending',
                        value: '${candidateCardUi.pending}',
                      ),
                      _MetricChip(
                        label: 'Linked',
                        value: '${candidateCardUi.linked}',
                      ),
                      _MetricChip(
                        label: 'Ignored',
                        value: '${candidateCardUi.ignored}',
                      ),
                      _MetricChip(
                        label: 'Unset',
                        value: '${candidateCardUi.unset}',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  candidateCardUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
                if (candidateCardUi.onBatchGenerateCandidateClips != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: candidateCardUi.batchGenerateCandidateClipsBusy
                        ? null
                        : candidateCardUi.onBatchGenerateCandidateClips,
                    icon: candidateCardUi.batchGenerateCandidateClipsBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.movie_creation_outlined),
                    label: Text(
                      candidateCardUi.batchGenerateCandidateClipsBusy
                          ? 'Submitting candidate clip batch jobs…'
                          : 'Batch-generate candidate clips (project defaults)',
                    ),
                  ),
                ],
                if (onOpenProjectsForCandidateAssets != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onOpenProjectsForCandidateAssets,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Open projects to manage assets'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (candidateComparePanelUi.visible) ...[
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Candidate compare', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  candidateComparePanelUi.headline,
                  style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                ),
                const SizedBox(height: 8),
                Text(
                  candidateComparePanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
                if (!candidateComparePanelUi.loading &&
                    !candidateComparePanelUi.unavailable &&
                    candidateComparePanelUi.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: candidateComparePanelUi.items
                        .map((item) => _CandidateCompareCard(item: item))
                        .toList(growable: false),
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
