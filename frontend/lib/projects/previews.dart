import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../../rust_api.dart';

String _projectAccessModeLabel(AppLocalizations l10n, String mode) {
  switch (mode) {
    case 'restricted':
      return l10n.projectsAccessModeRestricted;
    case 'inherited':
    default:
      return l10n.projectsAccessModeInherited;
  }
}

String _projectAccessRoleLabel(AppLocalizations l10n, String role) {
  switch (role) {
    case 'workspace_owner':
      return l10n.projectsRoleWorkspaceOwner;
    case 'workspace_admin':
      return l10n.projectsRoleWorkspaceAdmin;
    case 'project_owner':
      return l10n.projectsRoleProjectOwner;
    case 'editor':
      return l10n.projectsRoleEditor;
    case 'viewer':
      return l10n.projectsRoleViewer;
    case 'member':
    default:
      return l10n.projectsRoleMember;
  }
}

/// Groups the top-level project actions so the section stays focused on orchestration.
class ProjectsActionsBar extends StatelessWidget {
  const ProjectsActionsBar({
    super.key,
    required this.loadingProjects,
    required this.loadingProjectsSummary,
    required this.loadingArtStyles,
    required this.creatingProject,
    required this.onLoadProjects,
    required this.onLoadProjectsSummary,
    required this.onLoadArtStyles,
    required this.onOpenArtStylesWorkbench,
    required this.onOpenCreativeManualsWorkbench,
    required this.onOpenAgentMemoryWorkbench,
    required this.onCreateEmptyProject,
  });

  final bool loadingProjects;
  final bool loadingProjectsSummary;
  final bool loadingArtStyles;
  final bool creatingProject;
  final VoidCallback onLoadProjects;
  final VoidCallback onLoadProjectsSummary;
  final VoidCallback onLoadArtStyles;
  final VoidCallback onOpenArtStylesWorkbench;
  final VoidCallback onOpenCreativeManualsWorkbench;
  final VoidCallback onOpenAgentMemoryWorkbench;
  final VoidCallback onCreateEmptyProject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: (loadingProjects || creatingProject) ? null : onLoadProjects,
          child: Text(
            loadingProjects ? l10n.projectsLoading : l10n.projectsLoadProjectList,
          ),
        ),
        FilledButton.tonal(
          onPressed:
              (loadingProjectsSummary || creatingProject)
              ? null
              : onLoadProjectsSummary,
          child: Text(
            loadingProjectsSummary
                ? l10n.projectsLoading
                : l10n.projectsViewSummary,
          ),
        ),
        FilledButton.tonal(
          onPressed: (loadingArtStyles || creatingProject) ? null : onLoadArtStyles,
          child: Text(
            loadingArtStyles ? l10n.projectsLoading : l10n.projectsLoadArtStyles,
          ),
        ),
        FilledButton.tonal(
          onPressed: creatingProject ? null : onOpenArtStylesWorkbench,
          child: Text(l10n.projectsOpenArtStylesWorkbench),
        ),
        FilledButton.tonal(
          onPressed: creatingProject ? null : onOpenCreativeManualsWorkbench,
          child: Text(l10n.projectsOpenCreativeManualsWorkbench),
        ),
        FilledButton.tonal(
          onPressed: creatingProject ? null : onOpenAgentMemoryWorkbench,
          child: Text(l10n.projectsOpenAgentMemoryWorkbench),
        ),
        FilledButton.tonal(
          onPressed: (loadingProjects || creatingProject)
              ? null
              : onCreateEmptyProject,
          child: Text(
            creatingProject
                ? l10n.projectsCreating
                : l10n.projectsCreateEmptyProject,
          ),
        ),
      ],
    );
  }
}

/// Wraps the agent-memory regression probe used as a regression checkpoint.
class ProjectsCompatibilityPanel extends StatelessWidget {
  const ProjectsCompatibilityPanel({
    super.key,
    required this.outlineColor,
    required this.loadingAgentMemory,
    required this.onProbeAgentMemory,
  });

  final Color outlineColor;
  final bool loadingAgentMemory;
  final VoidCallback onProbeAgentMemory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l10n.projectsCompatibilityTitle),
      subtitle: Text(
        l10n.projectsCompatibilitySubtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: outlineColor),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: loadingAgentMemory ? null : onProbeAgentMemory,
            child: Text(
              loadingAgentMemory
                  ? l10n.projectsRequesting
                  : l10n.projectsCompatibilityProbeMemory,
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders the latest project and art-style summary lines returned by probes.
class ProjectsSummaryPreview extends StatelessWidget {
  const ProjectsSummaryPreview({
    super.key,
    this.projectsSummaryLine,
    this.artStylesLine,
  });

  final String? projectsSummaryLine;
  final String? artStylesLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (projectsSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.projectsSummaryLine(projectsSummaryLine!)),
        ],
        if (artStylesLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.projectsArtStylesLine(artStylesLine!)),
        ],
      ],
    );
  }
}

/// Composes the project summaries and preview lists into one display-only block.
class ProjectsOverviewPreview extends StatelessWidget {
  const ProjectsOverviewPreview({
    super.key,
    this.projectsSummaryLine,
    this.artStylesLine,
    this.artStyles,
    this.projects,
    this.agentMemoryBody,
    required this.onManageArtStyles,
    required this.onOpenProjectDetail,
  });

  final String? projectsSummaryLine;
  final String? artStylesLine;
  final List<ArtStyleRow>? artStyles;
  final List<ProjectRow>? projects;
  final String? agentMemoryBody;
  final VoidCallback onManageArtStyles;
  final ValueChanged<ProjectRow> onOpenProjectDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProjectsSummaryPreview(
          projectsSummaryLine: projectsSummaryLine,
          artStylesLine: artStylesLine,
        ),
        if (artStyles != null) ...[
          ProjectsArtStylesPreview(
            artStyles: artStyles!,
            onManage: onManageArtStyles,
          ),
        ],
        if (projects != null) ...[
          ProjectsListPreview(
            projects: projects!,
            onOpenProjectDetail: onOpenProjectDetail,
            agentMemoryBody: agentMemoryBody,
          ),
        ],
      ],
    );
  }
}

/// Shows a short list of available art styles with a quick path to management.
class ProjectsArtStylesPreview extends StatelessWidget {
  const ProjectsArtStylesPreview({
    super.key,
    required this.artStyles,
    required this.onManage,
  });

  final List<ArtStyleRow> artStyles;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          l10n.projectsArtStyleCount(artStyles.length),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        ...artStyles.take(5).map(
          (style) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(style.name),
            subtitle: Text(
              '#${style.numericId}'
              '${(style.label ?? '').isEmpty ? '' : ' · ${style.label}'}',
            ),
            trailing: TextButton(
              onPressed: onManage,
              child: Text(l10n.projectsArtStylesManage),
            ),
          ),
        ),
      ],
    );
  }
}

/// Displays project rows as a lightweight overview before entering detail pages.
class ProjectsListPreview extends StatelessWidget {
  const ProjectsListPreview({
    super.key,
    required this.projects,
    required this.onOpenProjectDetail,
    this.agentMemoryBody,
  });

  final List<ProjectRow> projects;
  final ValueChanged<ProjectRow> onOpenProjectDetail;
  final String? agentMemoryBody;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          l10n.projectsProjectCount(projects.length),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        ...projects.map(
          (project) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  project.name ??
                      l10n.projectsUnnamedProject(project.numericId),
                ),
                _ProjectAccessBadge(project: project),
              ],
            ),
            subtitle: Text(
              '#${project.numericId} · ${project.id} · ${_projectAccessRoleLabel(l10n, project.projectAccessRole)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpenProjectDetail(project),
          ),
        ),
        if (agentMemoryBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            '${l10n.projectsAgentMemoryPrefix}$agentMemoryBody',
          ),
        ],
      ],
    );
  }
}

class _ProjectAccessBadge extends StatelessWidget {
  const _ProjectAccessBadge({required this.project});

  final ProjectRow project;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final restricted = project.projectAccessMode == 'restricted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: restricted
            ? colorScheme.tertiaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${_projectAccessModeLabel(l10n, project.projectAccessMode)} · ${_projectAccessRoleLabel(l10n, project.projectAccessRole)}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: restricted
              ? colorScheme.onTertiaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
