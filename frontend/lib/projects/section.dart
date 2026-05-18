import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../project_studio/projects_studio_home.dart';
import 'create_project_dialog.dart';
import 'controller.dart';
import 'previews.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../team_workspaces/strings.dart';
import 'workbenches/agent_memory.dart';
import 'workbenches/art_styles_view.dart';
import 'workbenches/creative_manuals.dart';
import '../rust_api.dart';

part 'workbenches/art_styles.dart';
part 'workbenches/art_styles_helpers.dart';
part 'workbenches/art_styles_controllers.dart';

class ProjectsSection extends StatelessWidget {
  const ProjectsSection({
    super.key,
    required this.accessToken,
    required this.controller,
    required this.onOpenProjectDetail,
    required this.onOpenTeamWorkspaces,
    this.onOpenProjectStudio,
    this.productPresentation = false,
    this.currentWorkspaceName,
    this.currentWorkspaceType,
  });

  final String? accessToken;
  final ProjectsController controller;
  final ValueChanged<ProjectRow> onOpenProjectDetail;
  final VoidCallback onOpenTeamWorkspaces;
  /// Studio grid path: scope project + short-video space (no detail dialog).
  final ValueChanged<ProjectRow>? onOpenProjectStudio;
  /// Hides harness probes and manual load buttons in the product studio shell.
  final bool productPresentation;
  final String? currentWorkspaceName;
  final String? currentWorkspaceType;

  bool get _showEnterpriseProjectEmptyState =>
      currentWorkspaceType == 'enterprise' &&
      controller.projects != null &&
      controller.projects!.isEmpty;

  Future<void> _openArtStylesWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.projectsSnackSignInArtStyles)),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _ArtStylesWorkbenchDialog(
        accessToken: token,
        initialRows: controller.artStyles ?? const <ArtStyleRow>[],
        onRefreshParent: controller.loadArtStyles,
      ),
    );
  }

  Future<void> _openCreativeManualsWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.projectsSnackSignInCreativeManuals)),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) =>
          ProjectsCreativeManualsWorkbenchDialog(accessToken: token),
    );
  }

  Future<void> _openAgentMemoryWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.projectsSnackSignInAgentMemory)),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => ProjectsAgentMemoryWorkbenchDialog(
        accessToken: token,
        initialProjects: controller.projects ?? const <ProjectRow>[],
      ),
    );
  }

  Future<void> _createEmptyProject(BuildContext context) async {
    final fields = await showCreateProjectDialog(context);
    if (!context.mounted || fields == null) return;
    final created = await controller.createProjectWithFields(fields);
    if (!context.mounted || !created) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.projectsSnackProjectCreated)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (productPresentation && onOpenProjectStudio != null) {
      return ProjectsStudioHome(
        controller: controller,
        accessToken: accessToken,
        onOpenProjectStudio: onOpenProjectStudio!,
        onCreateProject: controller.createProjectWithFields,
        currentWorkspaceName: currentWorkspaceName,
        currentWorkspaceType: currentWorkspaceType,
        onOpenTeamWorkspaces: onOpenTeamWorkspaces,
      );
    }

    final l10n = resolveAppLocalizationsForErrors(context);
    final outline = Theme.of(context).colorScheme.outline;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.projectsListTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const RiskyOperationConfirmPrefsOverflowMenu(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.projectsListSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 8),
          if (productPresentation)
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: controller.creatingProject
                      ? null
                      : () => _createEmptyProject(context),
                  icon: const Icon(Icons.add),
                  label: Text(
                    controller.creatingProject
                        ? l10n.projectsCreating
                        : l10n.projectsCreateFirstEmpty,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.projectsLoadProjectList,
                  onPressed: controller.loadingProjects
                      ? null
                      : controller.loadProjects,
                  icon: controller.loadingProjects
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            )
          else ...<Widget>[
            ProjectsActionsBar(
              loadingProjects: controller.loadingProjects,
              loadingProjectsSummary: controller.loadingProjectsSummary,
              loadingArtStyles: controller.loadingArtStyles,
              creatingProject: controller.creatingProject,
              onLoadProjects: controller.loadProjects,
              onLoadProjectsSummary: controller.loadProjectsSummary,
              onLoadArtStyles: controller.loadArtStyles,
              onOpenArtStylesWorkbench: () => _openArtStylesWorkbench(context),
              onOpenCreativeManualsWorkbench: () =>
                  _openCreativeManualsWorkbench(context),
              onOpenAgentMemoryWorkbench: () =>
                  _openAgentMemoryWorkbench(context),
              onCreateEmptyProject: () => _createEmptyProject(context),
            ),
            const SizedBox(height: 8),
            ProjectsCompatibilityPanel(
              outlineColor: outline,
              loadingAgentMemory: controller.loadingAgentMemory,
              onProbeAgentMemory: controller.probeAgentMemory,
            ),
          ],
          if (_showEnterpriseProjectEmptyState) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.projectsEnterpriseEmptyTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    buildEnterpriseProjectsEmptyStateBody(
                      l10n,
                      currentWorkspaceName,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: controller.creatingProject
                            ? null
                            : () => _createEmptyProject(context),
                        child: Text(
                          controller.creatingProject
                              ? l10n.projectsCreating
                              : l10n.projectsCreateFirstEmpty,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: onOpenTeamWorkspaces,
                        child: Text(l10n.projectsOpenTeamWorkspaces),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          ProjectsOverviewPreview(
            projectsSummaryLine: controller.projectsSummaryLine,
            artStylesLine: controller.artStylesLine,
            artStyles: controller.artStyles,
            projects: controller.projects,
            agentMemoryBody: controller.agentMemoryBody,
            onManageArtStyles: () => _openArtStylesWorkbench(context),
            onOpenProjectDetail: onOpenProjectDetail,
          ),
        ],
      ),
    );
  }
}
