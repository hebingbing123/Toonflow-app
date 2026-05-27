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
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/components/studio_text_styles.dart';
import 'package:openflow_app/design_system/tokens.dart';

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
    this.currentProjectNumericId,
    this.onSelectProjectScope,
    this.onOpenProjectStudio,
    this.productPresentation = false,
    this.currentWorkspaceName,
    this.currentWorkspaceType,
    this.onOpenModelVendorSettings,
    this.onExploreDemo,
  });

  final String? accessToken;
  final ProjectsController controller;
  final ValueChanged<ProjectRow> onOpenProjectDetail;
  final VoidCallback onOpenTeamWorkspaces;
  final int? currentProjectNumericId;
  final Future<void> Function(ProjectRow row)? onSelectProjectScope;
  /// Studio grid path: scope project + short-video space (no detail dialog).
  final ValueChanged<ProjectRow>? onOpenProjectStudio;
  /// Hides harness probes and manual load buttons in the product studio shell.
  final bool productPresentation;
  final String? currentWorkspaceName;
  final String? currentWorkspaceType;
  final VoidCallback? onOpenModelVendorSettings;
  final VoidCallback? onExploreDemo;

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
    await showStudioDialog<void>(
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
    await showStudioDialog<void>(
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
    await showStudioDialog<void>(
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
        currentProjectNumericId: currentProjectNumericId,
        onSelectProjectScope: onSelectProjectScope,
        onOpenProjectStudio: onOpenProjectStudio!,
        onCreateProject: controller.createProjectWithFields,
        currentWorkspaceName: currentWorkspaceName,
        currentWorkspaceType: currentWorkspaceType,
        onOpenTeamWorkspaces: onOpenTeamWorkspaces,
        onOpenModelVendorSettings: onOpenModelVendorSettings,
        onExploreDemo: onExploreDemo,
      );
    }

    final l10n = resolveAppLocalizationsForErrors(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: StudioSpacing.sm),
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
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.projectsListSubtitle,
            style: studioHintStyle(context),
          ),
          const SizedBox(height: StudioSpacing.xs),
          if (productPresentation)
            Row(
              children: <Widget>[
                FilledButton.icon(
                  style: studioFormIconLabeledButtonStyle(context),
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
                const SizedBox(width: StudioSpacing.xs),
                IconButton(
                  tooltip: l10n.projectsLoadProjectList,
                  onPressed: controller.loadingProjects
                      ? null
                      : controller.loadProjects,
                  icon: controller.loadingProjects
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: StudioControlSize.progressStroke),
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
          ],
          StudioAsyncDataView(
            loading: controller.loadingProjects && controller.projects == null,
            loadingPlaceholder: StudioLoadingPlaceholder.grid,
            loadingItemCount: 4,
            loadingCrossAxisCount: 2,
            scrollableLoading: false,
            child: const SizedBox.shrink(),
          ),
          if (_showEnterpriseProjectEmptyState) ...[
            const SizedBox(height: StudioLayoutSpacing.listItem),
            StudioEmptyState.firstUse(
              title: l10n.projectsEnterpriseEmptyTitle,
              subtitle: buildEnterpriseProjectsEmptyStateBody(
                l10n,
                currentWorkspaceName,
              ),
              actionLabel: controller.creatingProject
                  ? l10n.projectsCreating
                  : l10n.projectsCreateFirstEmpty,
              onAction: controller.creatingProject
                  ? null
                  : () => _createEmptyProject(context),
              secondaryActionLabel: l10n.projectsOpenTeamWorkspaces,
              onSecondaryAction: onOpenTeamWorkspaces,
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
