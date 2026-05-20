import 'package:flutter/material.dart';

import '../design_system/components/studio_skeleton.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/theme.dart';
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
      return _LoadingGrid();
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
          return AspectRatio(aspectRatio: 1.06, child: card);
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
            ? 1.14
            : width >= 1280
            ? 1.1
            : 1.16;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
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
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.15,
      children: List<Widget>.generate(
        4,
        (_) => const StudioSkeleton(height: 220, borderRadius: 14),
      ),
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
    final studio = StudioColors.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title =
        project.name ?? l10n.projectsUnnamedProject(project.numericId);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
      child: InkWell(
        onTap: onSelect ?? onTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        child: Container(
          decoration: BoxDecoration(
            gradient: studio.panelGradient,
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            border: Border.all(
              color: selected ? tokens.primary : tokens.surfaceHighlight,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: selected
                    ? tokens.panelGlow.withValues(alpha: 0.14)
                    : tokens.panelGlowSecondary.withValues(alpha: 0.06),
                blurRadius: 20,
                spreadRadius: -14,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 16),
              Text(
                l10n.studioEnterStudio,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              const Spacer(),
              if ((project.intro ?? '').isNotEmpty)
                Text(
                  project.intro!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.bgInset.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: tokens.surfaceHighlight.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Text(
                      '#${project.numericId}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: selected
                          ? studio.signalGradient
                          : LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: <Color>[
                                tokens.primarySoft.withValues(alpha: 0.92),
                                tokens.accentSoft.withValues(alpha: 0.92),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? tokens.accent.withValues(alpha: 0.42)
                            : tokens.surfaceHighlight,
                      ),
                    ),
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              l10n.studioEnterStudio,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_outward,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
