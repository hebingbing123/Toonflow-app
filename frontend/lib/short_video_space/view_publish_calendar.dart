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
    final l10n = resolveAppLocalizationsForErrors(context);
    
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
        const SizedBox(height: StudioLayoutSpacing.stackMedium),
        Text(
          l10n.shortVideoSpaceScheduleCalendar,
          style: theme.textTheme.labelSmall?.copyWith(
            color: studioPanelMutedColor(context),
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        PublishScheduleCalendar(
          drafts: publishPanelUi.publishScheduleCalendarDrafts ?? [],
          busy: publishPanelUi.publishBusy,
          onDayTap: publishPanelUi.onPublishCalendarDayBulkSchedule!,
        ),
      ],
    );
  }
}
