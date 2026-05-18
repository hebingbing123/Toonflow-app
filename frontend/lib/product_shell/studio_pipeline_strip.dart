import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';
import '../shell/pipeline_step_chip.dart';

/// Refined production pipeline stepper for the product shell.
class StudioPipelineStrip extends StatelessWidget {
  const StudioPipelineStrip({
    super.key,
    required this.selectedPane,
    required this.onSelectPane,
    required this.jobsPaneEnabled,
    required this.qualityPaneEnabled,
    this.compact = false,
  });

  final ProductWorkspacePane selectedPane;
  final void Function(ProductWorkspacePane pane) onSelectPane;
  final bool jobsPaneEnabled;
  final bool qualityPaneEnabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final useWrapLayout = width >= 1400;
    final steps = <(ProductWorkspacePane, String, IconData)>[
      (
        ProductWorkspacePane.projects,
        l10n.productPipelineStripProjects,
        Icons.folder_special_outlined,
      ),
      (
        ProductWorkspacePane.scriptWorkspace,
        l10n.productPipelineStripScripts,
        Icons.menu_book_outlined,
      ),
      (
        ProductWorkspacePane.productionWorkspace,
        l10n.productPipelineStripProduction,
        Icons.theaters_outlined,
      ),
      (
        ProductWorkspacePane.tasks,
        l10n.productPipelineStripTasks,
        Icons.task_alt_outlined,
      ),
      if (jobsPaneEnabled)
        (
          ProductWorkspacePane.jobs,
          l10n.productPipelineStripJobs,
          Icons.cloud_queue_outlined,
        ),
      if (qualityPaneEnabled)
        (
          ProductWorkspacePane.quality,
          l10n.productPipelineStripQuality,
          Icons.verified_outlined,
        ),
      (
        ProductWorkspacePane.shortVideoSpace,
        l10n.productPipelineStripShortVideo,
        Icons.movie_creation_outlined,
      ),
    ];

    return Card(
      color: tokens.bgElevated,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? (useWrapLayout ? 18 : 16) : 18,
          vertical: compact ? (useWrapLayout ? 14 : 12) : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.route_outlined,
                  size: compact ? 18 : 20,
                  color: tokens.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.productPipelineStripTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 12),
            if (useWrapLayout)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  for (final step in steps)
                    PipelineStepChip(
                      useStudioTokens: true,
                      label: step.$2,
                      icon: step.$3,
                      selected: selectedPane == step.$1,
                      onSelected: (_) => onSelectPane(step.$1),
                    ),
                ],
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (final step in steps)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: PipelineStepChip(
                          useStudioTokens: true,
                          label: step.$2,
                          icon: step.$3,
                          selected: selectedPane == step.$1,
                          onSelected: (_) => onSelectPane(step.$1),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
