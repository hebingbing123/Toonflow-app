import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'studio_step.dart';

/// Project cockpit metrics with step-aware filtering and compact mode on script step.
class ProjectStudioCockpitPanel extends StatefulWidget {
  const ProjectStudioCockpitPanel({
    super.key,
    required this.home,
    required this.currentStep,
    required this.onExecuteAction,
    required this.metricActionBuilder,
    required this.onExecuteStarter,
  });

  final ProjectHome home;
  final StudioStep currentStep;
  final ValueChanged<ProjectHomeAction> onExecuteAction;
  final ProjectHomeAction? Function(ProjectHomeMetric metric)
  metricActionBuilder;
  final ValueChanged<ProjectHomeStarterTemplate> onExecuteStarter;

  @override
  State<ProjectStudioCockpitPanel> createState() =>
      _ProjectStudioCockpitPanelState();
}

class _ProjectStudioCockpitPanelState extends State<ProjectStudioCockpitPanel> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.currentStep == StudioStep.script;
  }

  @override
  void didUpdateWidget(covariant ProjectStudioCockpitPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      setState(() {
        _expanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cockpit = widget.home.cockpit;
    final filtered = _CockpitStepFilter.filter(
      cockpit: cockpit,
      step: widget.currentStep,
    );

    if (!_expanded) {
      final dense =
          widget.currentStep == StudioStep.deliver ||
          widget.currentStep == StudioStep.quality;
      return _CompactCockpitBar(
        summary: filtered.compactSummary,
        primaryAction: cockpit.primaryAction,
        showPrimaryAction: widget.currentStep != StudioStep.script,
        dense: dense,
        onExecuteAction: widget.onExecuteAction,
        onExpand: () => setState(() => _expanded = true),
        expandLabel: l10n.studioCockpitExpand,
      );
    }

    return _ExpandedCockpitCard(
      cockpit: cockpit,
      filtered: filtered,
      currentStep: widget.currentStep,
      onExecuteAction: widget.onExecuteAction,
      metricActionBuilder: widget.metricActionBuilder,
      onExecuteStarter: widget.onExecuteStarter,
      onCollapse: () => setState(() => _expanded = false),
      collapseLabel: l10n.studioCockpitCollapse,
    );
  }
}

class _CockpitStepFilter {
  const _CockpitStepFilter({
    required this.metrics,
    required this.secondaryActions,
    required this.starters,
    required this.compactSummary,
    required this.showHeadline,
  });

  final List<ProjectHomeMetric> metrics;
  final List<ProjectHomeAction> secondaryActions;
  final List<ProjectHomeStarterTemplate> starters;
  final String compactSummary;
  final bool showHeadline;

  static _CockpitStepFilter filter({
    required ProjectHomeCockpit cockpit,
    required StudioStep step,
  }) {
    final metrics = _filterMetrics(cockpit.metrics, step);
    final secondaryActions = _filterActions(cockpit.secondaryActions, step);
    final starters = _filterStarters(cockpit.starterTemplates, step);
    ProjectHomeMetric? contentMetric;
    for (final metric in metrics) {
      if (metric.key.trim().toLowerCase() == 'content') {
        contentMetric = metric;
        break;
      }
    }
    final compactSummary =
        contentMetric?.value ??
        (metrics.isEmpty ? cockpit.subheadline : metrics.first.value);
    return _CockpitStepFilter(
      metrics: metrics,
      secondaryActions: secondaryActions,
      starters: starters,
      compactSummary: compactSummary,
      showHeadline: step != StudioStep.script,
    );
  }

  static List<ProjectHomeMetric> _filterMetrics(
    List<ProjectHomeMetric> metrics,
    StudioStep step,
  ) {
    if (step == StudioStep.deliver || step == StudioStep.quality) {
      return metrics;
    }
    final filtered = metrics
        .where((m) => _isRelevantForStep(m.launchIntent?.targetStep, step))
        .toList(growable: false);
    return filtered.isNotEmpty ? filtered : metrics;
  }

  static List<ProjectHomeAction> _filterActions(
    List<ProjectHomeAction> actions,
    StudioStep step,
  ) {
    if (step == StudioStep.deliver || step == StudioStep.quality) {
      return actions;
    }
    final filtered = actions
        .where((a) => _isRelevantForStep(a.targetStep, step))
        .toList(growable: false);
    return filtered.isNotEmpty ? filtered : actions;
  }

  static List<ProjectHomeStarterTemplate> _filterStarters(
    List<ProjectHomeStarterTemplate> starters,
    StudioStep step,
  ) {
    if (step == StudioStep.script) {
      // Shown in [CreatorStarterTemplatesStrip] on the script step (T6).
      return const <ProjectHomeStarterTemplate>[];
    }
    if (step == StudioStep.deliver || step == StudioStep.quality) {
      return starters;
    }
    final filtered = starters
        .where((s) => _isRelevantForStep(s.targetStep, step))
        .toList(growable: false);
    return filtered.isNotEmpty ? filtered : starters;
  }

  static bool _isRelevantForStep(String? targetStep, StudioStep step) {
    final slug = (targetStep ?? '').trim().toLowerCase();
    if (slug.isEmpty || slug == 'tasks') {
      return false;
    }
    return slug == step.slug;
  }
}

class _CompactCockpitBar extends StatelessWidget {
  const _CompactCockpitBar({
    required this.summary,
    required this.primaryAction,
    required this.onExecuteAction,
    required this.onExpand,
    required this.expandLabel,
    this.showPrimaryAction = true,
    this.dense = false,
  });

  final String summary;
  final ProjectHomeAction primaryAction;
  final ValueChanged<ProjectHomeAction> onExecuteAction;
  final VoidCallback onExpand;
  final String expandLabel;
  final bool showPrimaryAction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < (dense ? 780 : 680);
          final summaryText = Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
          final expandButton = TextButton(
            onPressed: onExpand,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 10 : 12,
                vertical: dense ? 6 : 8,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: dense
                  ? VisualDensity.compact
                  : VisualDensity.standard,
            ),
            child: Text(expandLabel),
          );
          final primaryButton = FilledButton(
            onPressed: () => onExecuteAction(primaryAction),
            style: FilledButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 12 : 14,
                vertical: dense ? 8 : 10,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: dense
                  ? VisualDensity.compact
                  : VisualDensity.standard,
            ),
            child: Text(primaryAction.ctaLabel),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                summaryText,
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    expandButton,
                    if (showPrimaryAction) primaryButton,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(child: summaryText),
              const SizedBox(width: 6),
              expandButton,
              if (showPrimaryAction) ...<Widget>[
                const SizedBox(width: 6),
                primaryButton,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExpandedCockpitCard extends StatelessWidget {
  const _ExpandedCockpitCard({
    required this.cockpit,
    required this.filtered,
    required this.currentStep,
    required this.onExecuteAction,
    required this.metricActionBuilder,
    required this.onExecuteStarter,
    this.onCollapse,
    this.collapseLabel,
  });

  final ProjectHomeCockpit cockpit;
  final _CockpitStepFilter filtered;
  final StudioStep currentStep;
  final ValueChanged<ProjectHomeAction> onExecuteAction;
  final ProjectHomeAction? Function(ProjectHomeMetric metric)
  metricActionBuilder;
  final ValueChanged<ProjectHomeStarterTemplate> onExecuteStarter;
  final VoidCallback? onCollapse;
  final String? collapseLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final secondaryActions = filtered.secondaryActions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  filtered.showHeadline
                      ? cockpit.headline
                      : AppLocalizations.of(context)!.studioCockpitScriptTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onCollapse != null && collapseLabel != null)
                TextButton(onPressed: onCollapse, child: Text(collapseLabel!)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            cockpit.subheadline,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _CockpitActionRow(
            primaryAction: cockpit.primaryAction,
            secondaryActions: secondaryActions,
            onExecuteAction: onExecuteAction,
          ),
          if (filtered.metrics.isNotEmpty ||
              filtered.starters.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final maxWidth = constraints.maxWidth;
                var columns = 1;
                if (maxWidth >= 1200) {
                  columns = 3;
                } else if (maxWidth >= 720) {
                  columns = 2;
                }
                final itemWidth =
                    (maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: <Widget>[
                    ...filtered.metrics.map(
                      (metric) => _CockpitMetricTile(
                        width: itemWidth,
                        metric: metric,
                        action: metricActionBuilder(metric),
                        onExecuteAction: onExecuteAction,
                      ),
                    ),
                    ...filtered.starters.map(
                      (starter) => _CockpitStarterTile(
                        width: itemWidth,
                        starter: starter,
                        onExecuteStarter: onExecuteStarter,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CockpitActionRow extends StatelessWidget {
  const _CockpitActionRow({
    required this.primaryAction,
    required this.secondaryActions,
    required this.onExecuteAction,
  });

  final ProjectHomeAction primaryAction;
  final List<ProjectHomeAction> secondaryActions;
  final ValueChanged<ProjectHomeAction> onExecuteAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton(
          onPressed: () => onExecuteAction(primaryAction),
          child: Text(primaryAction.ctaLabel),
        ),
        ...secondaryActions
            .take(2)
            .map(
              (action) => OutlinedButton(
                onPressed: () => onExecuteAction(action),
                child: Text(action.ctaLabel),
              ),
            ),
      ],
    );
  }
}

class _CockpitMetricTile extends StatelessWidget {
  const _CockpitMetricTile({
    required this.metric,
    required this.width,
    this.action,
    this.onExecuteAction,
  });

  final ProjectHomeMetric metric;
  final double width;
  final ProjectHomeAction? action;
  final ValueChanged<ProjectHomeAction>? onExecuteAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final card = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            metric.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              action!.ctaLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    return SizedBox(
      width: width,
      child: action == null || onExecuteAction == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onExecuteAction!(action!),
              child: card,
            ),
    );
  }
}

class _CockpitStarterTile extends StatelessWidget {
  const _CockpitStarterTile({
    required this.starter,
    required this.onExecuteStarter,
    required this.width,
  });

  final ProjectHomeStarterTemplate starter;
  final ValueChanged<ProjectHomeStarterTemplate> onExecuteStarter;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tokens.bgInset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              starter.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              starter.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: () => onExecuteStarter(starter),
              child: Text(starter.ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}
