import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'navigation_controller.dart';

/// Platform-level entry points for the short-drama production chain (Moneyprinter-style),
/// independent of any single feature module.
class PlatformShortDramaPipelineStrip extends StatelessWidget {
  const PlatformShortDramaPipelineStrip({
    super.key,
    required this.onSelectPane,
    required this.jobsPaneEnabled,
    required this.qualityPaneEnabled,
  });

  final void Function(ProductWorkspacePane pane) onSelectPane;
  final bool jobsPaneEnabled;
  final bool qualityPaneEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final steps = <(ProductWorkspacePane, String, IconData)>[
      (ProductWorkspacePane.projects, l10n.productPipelineStripProjects, Icons.folder_special_outlined),
      (ProductWorkspacePane.scriptWorkspace, l10n.productPipelineStripScripts, Icons.menu_book_outlined),
      (
        ProductWorkspacePane.productionWorkspace,
        l10n.productPipelineStripProduction,
        Icons.movie_filter_outlined,
      ),
      (ProductWorkspacePane.tasks, l10n.productPipelineStripTasks, Icons.task_alt_outlined),
      (ProductWorkspacePane.jobs, l10n.productPipelineStripJobs, Icons.cloud_queue_outlined),
      (ProductWorkspacePane.quality, l10n.productPipelineStripQuality, Icons.verified_outlined),
      (
        ProductWorkspacePane.shortVideoSpace,
        l10n.productPipelineStripShortVideo,
        Icons.video_library_outlined,
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.productPipelineStripTitle, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            l10n.productPipelineStripSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: steps
                .map((s) {
                  final enabled =
                      (s.$1 != ProductWorkspacePane.jobs || jobsPaneEnabled) &&
                      (s.$1 != ProductWorkspacePane.quality ||
                          qualityPaneEnabled);
                  return ActionChip(
                    avatar: Icon(s.$3, size: 18),
                    label: Text(s.$2),
                    onPressed: enabled ? () => onSelectPane(s.$1) : null,
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
