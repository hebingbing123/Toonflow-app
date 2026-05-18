import 'package:flutter/material.dart';

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
    this.loading = false,
    this.progressForProject,
  });

  final List<ProjectRow> projects;
  final ValueChanged<ProjectRow> onOpenProject;
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
        final crossAxisCount = switch (projects.length) {
          <= 1 => 1,
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
    required this.onTap,
  });

  final ProjectRow project;
  final int completedSteps;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title =
        project.name ?? l10n.projectsUnnamedProject(project.numericId);

    return Material(
      color: tokens.bgElevated,
      borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            border: Border.all(color: tokens.borderSubtle),
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
                  StudioStepProgressRing(completedSteps: completedSteps),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.studioEnterStudio,
                style: Theme.of(context).textTheme.bodySmall,
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
                  Text(
                    '#${project.numericId}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text(
                    l10n.studioEnterStudio,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: tokens.primary),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 18, color: tokens.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
