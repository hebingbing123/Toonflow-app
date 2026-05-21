import 'package:flutter/material.dart';

import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_skeleton.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'studio_step_progress_ring.dart';

class ProjectsGridView extends StatelessWidget {
  const ProjectsGridView({
    super.key,
    required this.projects,
    required this.onOpenProject,
    this.currentProjectNumericId,
    this.onSelectProject,
    this.loading = false,
    this.progressForProject,
  });

  final List<ProjectRow> projects;
  final ValueChanged<ProjectRow> onOpenProject;
  final int? currentProjectNumericId;
  final Future<void> Function(ProjectRow project)? onSelectProject;
  final bool loading;
  final int Function(ProjectRow project)? progressForProject;

  @override
  Widget build(BuildContext context) {
    if (loading && projects.isEmpty) {
      return const _LoadingGrid();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (projects.length == 1) {
          final card = _ProjectGridCard(
            project: projects.first,
            completedSteps: progressForProject?.call(projects.first) ?? 0,
            selected: currentProjectNumericId == projects.first.numericId,
            onSelect: onSelectProject == null
                ? null
                : () => onSelectProject!(projects.first),
            onTap: () => onOpenProject(projects.first),
          );
          if (width >= 1100) {
            return Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: width >= 1680 ? 860 : 760,
                ),
                child: AspectRatio(
                  aspectRatio: width >= 1680 ? 1.34 : 1.22,
                  child: card,
                ),
              ),
            );
          }
          return AspectRatio(
            aspectRatio: width < 620 ? 0.92 : 1.0,
            child: card,
          );
        }
        final crossAxisCount = switch (projects.length) {
          2 => width >= 840 ? 2 : 1,
          _ =>
            width >= 2100
                ? 5
                : width >= 1680
                ? 4
                : width >= 1260
                ? 3
                : width >= 920
                ? 2
                : 1,
        };
        final childAspectRatio = width >= 2100
            ? 1.18
            : width >= 1680
            ? 1.12
            : width >= 1280
            ? 1.04
            : width >= 920
            ? 1.0
            : width >= 620
            ? 0.96
            : 0.9;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: StudioLayoutSpacing.stackMedium,
            crossAxisSpacing: StudioLayoutSpacing.stackMedium,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            final steps = progressForProject?.call(project) ?? 0;
            return _ProjectGridCard(
              project: project,
              completedSteps: steps,
              selected: currentProjectNumericId == project.numericId,
              onSelect: onSelectProject == null
                  ? null
                  : () => onSelectProject!(project),
              onTap: () => onOpenProject(project),
            );
          },
        );
      },
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 920 ? 2 : 1;
        final childAspectRatio = width >= 920 ? 1.05 : 0.9;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: StudioSpacing.sm,
          crossAxisSpacing: StudioSpacing.sm,
          childAspectRatio: childAspectRatio,
          children: List<Widget>.generate(
            crossAxisCount == 1 ? 2 : 4,
            (_) => const StudioSkeleton(height: 220, borderRadius: 14),
          ),
        );
      },
    );
  }
}

class _ProjectGridCard extends StatelessWidget {
  const _ProjectGridCard({
    required this.project,
    required this.completedSteps,
    this.selected = false,
    this.onSelect,
    required this.onTap,
  });

  final ProjectRow project;
  final int completedSteps;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title =
        project.name ?? l10n.projectsUnnamedProject(project.numericId);
    final summary = (project.intro ?? '').trim();
    final focusLabel = _projectFocusLabel(l10n, completedSteps);
    final fallbackSummary = _projectFocusSummary(l10n, completedSteps);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
      child: InkWell(
        onTap: onSelect ?? onTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        child: Container(
          decoration: BoxDecoration(
            color: tokens.bgSurface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            border: Border.all(
              color: selected ? tokens.primary : tokens.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: null,
          ),
          padding: const EdgeInsets.all(StudioLayoutSpacing.section - 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: studioCardTitleStyle(context),
                    ),
                  ),
                  if (selected) ...<Widget>[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 18, color: tokens.primary),
                    const SizedBox(width: 8),
                  ],
                  StudioStepProgressRing(completedSteps: completedSteps),
                ],
              ),
              const SizedBox(height: StudioSpacing.sm),
              Text(
                summary.isNotEmpty ? summary : fallbackSummary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: StudioSpacing.sm),
              Wrap(
                spacing: StudioSpacing.xs,
                runSpacing: StudioSpacing.xs,
                children: <Widget>[
                  _ProjectMetaChip(
                    label: '#${project.numericId}',
                    color: tokens.textSecondary,
                  ),
                  _ProjectMetaChip(
                    label: focusLabel,
                    color: selected ? tokens.textPrimary : tokens.primary,
                    backgroundColor: selected
                        ? tokens.primarySoft.withValues(alpha: 0.84)
                        : tokens.bgInset.withValues(alpha: 0.9),
                    borderColor: selected
                        ? tokens.primary.withValues(alpha: 0.4)
                        : tokens.surfaceHighlight.withValues(alpha: 0.9),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: StudioPrimaryButton(
                  label: l10n.studioEnterStudio,
                  icon: Icons.arrow_outward,
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _projectFocusLabel(AppLocalizations l10n, int completedSteps) {
    final clamped = completedSteps.clamp(0, 5);
    return switch (clamped) {
      0 => l10n.studioStepScriptShort,
      1 => l10n.studioStepArtShort,
      2 => l10n.studioStepAssetsShort,
      3 => l10n.studioStepStoryboardShort,
      4 => l10n.studioStepVideoShort,
      _ => l10n.studioStepDeliverShort,
    };
  }

  String _projectFocusSummary(AppLocalizations l10n, int completedSteps) {
    final clamped = completedSteps.clamp(0, 5);
    return switch (clamped) {
      0 => l10n.studioStepScriptBody,
      1 => l10n.studioStepArtBody,
      2 => l10n.studioStepAssetsBody,
      3 => l10n.studioStepStoryboardBody,
      4 => l10n.studioStepVideoBody,
      _ => l10n.studioContinueCreating,
    };
  }
}

class _ProjectMetaChip extends StatelessWidget {
  const _ProjectMetaChip({
    required this.label,
    required this.color,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs + 2,
        vertical: StudioSpacing.xs - 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.bgInset.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor ?? tokens.surfaceHighlight.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
