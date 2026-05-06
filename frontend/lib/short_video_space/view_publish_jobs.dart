part of 'view.dart';

/// Job status and monitoring widget
class _PublishJobsPanel extends StatelessWidget {
  const _PublishJobsPanel({
    required this.publishPanelUi,
  });

  final ShortVideoPublishPanelUi publishPanelUi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    
    if (!publishPanelUi.visible ||
        publishPanelUi.loading ||
        publishPanelUi.unavailable ||
        publishPanelUi.jobLines.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '发布作业',
              style: theme.textTheme.labelSmall?.copyWith(color: outline),
            ),
            const Spacer(),
            // P11: Delivery mode filter chips
            if (publishPanelUi.jobsByDeliveryMode.isNotEmpty)
              Wrap(
                spacing: 4,
                children: publishPanelUi.jobsByDeliveryMode.entries.map((e) {
                  final isSelected = publishPanelUi.deliveryModeFilter == e.key;
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DeliveryModeBadge(deliveryMode: e.key, small: true),
                        const SizedBox(width: 4),
                        Text('${e.value}', style: theme.textTheme.labelSmall),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: publishPanelUi.onDeliveryModeFilterChanged == null
                        ? null
                        : (_) => publishPanelUi.onDeliveryModeFilterChanged?.call(e.key),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  );
                }).toList(),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final line in publishPanelUi.jobLines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
