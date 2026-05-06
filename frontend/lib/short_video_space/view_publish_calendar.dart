part of 'view.dart';

/// Calendar scheduling UI widget
class _PublishCalendarPanel extends StatelessWidget {
  const _PublishCalendarPanel({
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
        (publishPanelUi.publishScheduleCalendarDrafts?.isEmpty ?? true) ||
        publishPanelUi.onPublishCalendarDayBulkSchedule == null) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          '排程月历（按本地日历日计数；点选某日批量写入定时）',
          style: theme.textTheme.labelSmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        PublishScheduleCalendar(
          drafts: publishPanelUi.publishScheduleCalendarDrafts ?? [],
          busy: publishPanelUi.publishBusy,
          onDayTap: publishPanelUi.onPublishCalendarDayBulkSchedule!,
        ),
      ],
    );
  }
}
