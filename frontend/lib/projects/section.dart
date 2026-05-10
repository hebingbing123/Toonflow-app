import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'create_project_dialog.dart';
import 'controller.dart';
import 'previews.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../team_workspaces/strings.dart';
import 'workbenches/agent_memory.dart';
import 'workbenches/art_styles_view.dart';
import 'workbenches/creative_manuals.dart';
import '../../rust_api.dart';

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
    this.currentWorkspaceName,
    this.currentWorkspaceType,
  });

  final String? accessToken;
  final ProjectsController controller;
  final ValueChanged<ProjectRow> onOpenProjectDetail;
  final VoidCallback onOpenTeamWorkspaces;
  final String? currentWorkspaceName;
  final String? currentWorkspaceType;

  bool get _showEnterpriseProjectEmptyState =>
      currentWorkspaceType == 'enterprise' &&
      controller.projects != null &&
      controller.projects!.isEmpty;

  Future<void> _openArtStylesWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取美术风格')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取创作手册')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取 Agent 记忆')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已创建项目')));
  }

  @override
  Widget build(BuildContext context) {
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
                  '项目列表',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: '本机客户端偏好',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '查看项目、摘要、美术风格与创作手册，并进入项目详情继续编辑。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 8),
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
                    '当前团队空间还没有项目',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    buildEnterpriseProjectsEmptyStateBody(currentWorkspaceName),
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
                          controller.creatingProject ? '创建中…' : '先创建空项目',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: onOpenTeamWorkspaces,
                        child: const Text('打开团队工作区'),
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
