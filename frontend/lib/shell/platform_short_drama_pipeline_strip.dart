import 'package:flutter/material.dart';

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
    final steps = <(ProductWorkspacePane, String, IconData)>[
      (ProductWorkspacePane.projects, '项目', Icons.folder_special_outlined),
      (ProductWorkspacePane.scriptWorkspace, '脚本', Icons.menu_book_outlined),
      (
        ProductWorkspacePane.productionWorkspace,
        '制作',
        Icons.movie_filter_outlined,
      ),
      (ProductWorkspacePane.tasks, '任务', Icons.task_alt_outlined),
      (ProductWorkspacePane.jobs, '作业', Icons.cloud_queue_outlined),
      (ProductWorkspacePane.quality, '质量', Icons.verified_outlined),
      (
        ProductWorkspacePane.shortVideoSpace,
        '短视频',
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
          Text('短剧生产平台链', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            '从项目配置到脚本、制作、任务与质量评审的统一入口；短视频 Space 用于编排与成片相关能力。',
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
