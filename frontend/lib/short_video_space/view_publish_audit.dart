part of 'view.dart';

/// Audit log display widget
class _PublishAuditPanel extends StatelessWidget {
  const _PublishAuditPanel({
    required this.publishPanelUi,
  });

  final ShortVideoPublishPanelUi publishPanelUi;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    
    if (!publishPanelUi.visible ||
        publishPanelUi.loading ||
        publishPanelUi.unavailable ||
        publishPanelUi.publishOverviewLines.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: StudioLayoutSpacing.inlineGap),
        Text(
          l10n.shortVideoPublishAuditOverviewTitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: studioPanelMutedColor(context),
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        // P11: Delivery mode breakdown
        if (publishPanelUi.jobsByDeliveryMode.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(StudioSpacing.xs),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortVideoPublishAuditDeliveryModeTitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Wrap(
                  spacing: StudioSpacing.radiusComfort,
                  runSpacing: StudioSpacing.xs,
                  children: publishPanelUi.jobsByDeliveryMode.entries.map((e) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DeliveryModeBadge(deliveryMode: e.key),
                        const SizedBox(width: StudioSpacing.xs),
                        Text(
                          l10n.shortVideoPublishAuditJobCount(e.value),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
        ],
        for (final line in publishPanelUi.publishOverviewLines)
          Padding(
            padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
            child: Text(
              line,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
