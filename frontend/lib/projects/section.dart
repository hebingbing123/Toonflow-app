import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'previews.dart';
import 'workbenches/agent_memory.dart';
import 'workbenches/art_styles_view.dart';
import 'workbenches/creative_manuals.dart';
import '../../rust_api.dart';

part 'workbenches/art_styles.dart';

class ProjectsSection extends StatelessWidget {
  const ProjectsSection({
    super.key,
    required this.accessToken,
    required this.controller,
    required this.onOpenProjectDetail,
  });

  final String? accessToken;
  final ProjectsController controller;
  final ValueChanged<ProjectRow> onOpenProjectDetail;

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
    final created = await controller.createEmptyProject();
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
          Text('项目列表', style: Theme.of(context).textTheme.titleSmall),
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
