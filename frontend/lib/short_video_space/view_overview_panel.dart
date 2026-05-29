part of 'view.dart';

/// Current project overview + suggested migration order (side-by-side on wide screens).
class _OverviewMigrationPanel extends StatelessWidget {
  const _OverviewMigrationPanel({
    required this.spaceOverviewSummary,
    required this.overviewMetrics,
    required this.qualitySummaryLine,
    required this.badCaseMetrics,
    required this.recentTaskLines,
    required this.migrationSummary,
    required this.onOpenProjects,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
    required this.runningJobCount,
  });

  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;
  final String migrationSummary;
  final VoidCallback onOpenProjects;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;
  final int runningJobCount;

  @override
  Widget build(BuildContext context) {
    final overview = _ProjectOverviewSection(
      spaceOverviewSummary: spaceOverviewSummary,
      overviewMetrics: overviewMetrics,
      qualitySummaryLine: qualitySummaryLine,
      badCaseMetrics: badCaseMetrics,
      recentTaskLines: recentTaskLines,
    );
    final migration = _MigrationOrderSection(
      migrationSummary: migrationSummary,
      onOpenProjects: onOpenProjects,
      onOpenScriptWorkspace: onOpenScriptWorkspace,
      onOpenProductionWorkspace: onOpenProductionWorkspace,
      onOpenTasks: onOpenTasks,
      onOpenQuality: onOpenQuality,
      runningJobCount: runningJobCount,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= kStudioTwoColumnMinWidth;
        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 11,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        width: 1,
                        color: studioPanelBorderColor(context).withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.only(
                    right: StudioSpacing.md,
                  ),
                  child: overview,
                ),
              ),
              const SizedBox(width: StudioSpacing.md),
              Expanded(flex: 9, child: migration),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            overview,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: StudioSpacing.md),
              child: Divider(
                height: 1,
                color: studioPanelBorderColor(context).withValues(alpha: 0.65),
              ),
            ),
            migration,
          ],
        );
      },
    );
  }
}

class _ProjectOverviewSection extends StatelessWidget {
  const _ProjectOverviewSection({
    required this.spaceOverviewSummary,
    required this.overviewMetrics,
    required this.qualitySummaryLine,
    required this.badCaseMetrics,
    required this.recentTaskLines,
  });

  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shortVideoSpaceCurrentProjectOverview,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          spaceOverviewSummary,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: StudioSpacing.sm),
        StudioResponsiveChipGrid(
          entranceKey: overviewMetrics.length,
          children: overviewMetrics
              .map((item) => _MetricChip(label: item.label, value: item.value))
              .toList(growable: false),
        ),
        const SizedBox(height: StudioSpacing.sm),
        Text(
          qualitySummaryLine,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        if (badCaseMetrics.isNotEmpty) ...[
          const SizedBox(height: StudioSpacing.radiusComfort),
          Text(
            l10n.shortVideoSpaceRecentBadCaseTrends,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: StudioSpacing.xs),
          StudioResponsiveChipGrid(
            entranceKey: badCaseMetrics.length,
            children: badCaseMetrics
                .map(
                  (item) => _MetricChip(label: item.label, value: item.value),
                )
                .toList(growable: false),
          ),
        ],
        if (recentTaskLines.isNotEmpty) ...[
          const SizedBox(height: StudioSpacing.sm),
          Text(
            l10n.shortVideoSpaceRecentTaskFlow,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: StudioSpacing.xs),
          for (final (index, line) in recentTaskLines.indexed)
            studioStaggeredItem(
              index,
              entranceKey: recentTaskLines.length,
              child: Padding(
                padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 10,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                    Expanded(
                      child: Text(line, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _MigrationOrderSection extends StatelessWidget {
  const _MigrationOrderSection({
    required this.migrationSummary,
    required this.onOpenProjects,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
    required this.runningJobCount,
  });

  final String migrationSummary;
  final VoidCallback onOpenProjects;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;
  final int runningJobCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shortVideoSpaceSectionMigrationOrder,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          migrationSummary,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: StudioSpacing.sm),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: onOpenProjects,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.shortVideoSpaceNavProjects),
            ),
            OutlinedButton.icon(
              onPressed: onOpenScriptWorkspace,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(l10n.shortVideoSpaceNavScriptWorkspace),
            ),
            OutlinedButton.icon(
              onPressed: onOpenProductionWorkspace,
              icon: const Icon(Icons.movie_creation_outlined),
              label: Text(l10n.shortVideoSpaceNavProductionWorkspace),
            ),
            OutlinedButton.icon(
              onPressed: onOpenTasks,
              icon: const Icon(Icons.checklist_outlined),
              label: Text(
                runningJobCount > 0
                    ? '${l10n.shortVideoSpaceNavTaskCenter} ($runningJobCount)'
                    : l10n.shortVideoSpaceNavTaskCenter,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onOpenQuality,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.shortVideoSpaceNavQualityReviews),
            ),
          ],
        ),
      ],
    );
  }
}

/// Production overview and stats panel widget
