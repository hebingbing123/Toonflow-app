import 'package:flutter/material.dart';

import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../rust_api.dart';
import 'navigation_controller.dart';
import 'pipeline_step_chip.dart';

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
    final narrow = MediaQuery.sizeOf(context).width < 520;
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
        Icons.movie_filter_outlined,
      ),
      (
        ProductWorkspacePane.tasks,
        l10n.productPipelineStripTasks,
        Icons.task_alt_outlined,
      ),
      (
        ProductWorkspacePane.jobs,
        l10n.productPipelineStripJobs,
        Icons.cloud_queue_outlined,
      ),
      (
        ProductWorkspacePane.quality,
        l10n.productPipelineStripQuality,
        Icons.verified_outlined,
      ),
      (
        ProductWorkspacePane.shortVideoSpace,
        l10n.productPipelineStripShortVideo,
        Icons.ios_share_outlined,
      ),
    ];
    final stepChips = steps
        .map((step) {
          final enabled =
              (step.$1 != ProductWorkspacePane.jobs || jobsPaneEnabled) &&
              (step.$1 != ProductWorkspacePane.quality || qualityPaneEnabled);
          return PipelineStepChip(
            compact: narrow,
            label: step.$2,
            icon: step.$3,
            selected: false,
            enabled: enabled,
            onSelected: enabled ? (_) => onSelectPane(step.$1) : null,
          );
        })
        .toList(growable: false);
    final tokens = StudioTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: StudioLayoutSpacing.cardInner - 4,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: studioPanelBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.productPipelineStripTitle,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.productPipelineStripSubtitle,
            style: studioMutedBodySmall(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (var i = 0; i < stepChips.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == stepChips.length - 1 ? 0 : 8,
                    ),
                    child: stepChips[i],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
