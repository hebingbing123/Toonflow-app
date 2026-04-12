import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'previews.dart';
import 'workbenches/agent_memory.dart';
import 'workbenches/creative_manuals.dart';
import '../../rust_api.dart';

part 'workbenches/art_styles.dart';
part 'workbenches/art_styles_view.dart';

class ProjectsSection extends StatelessWidget {
  const ProjectsSection({
    super.key,
    required this.accessToken,
    required this.loadingProjects,
    required this.loadingProjectsSummary,
    required this.loadingArtStyles,
    required this.creatingProject,
    required this.loadingAgentMemory,
    required this.projects,
    required this.artStyles,
    required this.projectsSummaryLine,
    required this.artStylesLine,
    required this.agentMemoryBody,
    required this.onLoadProjects,
    required this.onLoadProjectsSummary,
    required this.onLoadArtStyles,
    required this.onCreateEmptyProject,
    required this.onOpenProjectDetail,
    required this.onProbeAgentMemory,
  });

  final String? accessToken;
  final bool loadingProjects;
  final bool loadingProjectsSummary;
  final bool loadingArtStyles;
  final bool creatingProject;
  final bool loadingAgentMemory;
  final List<ProjectRow>? projects;
  final List<ArtStyleRow>? artStyles;
  final String? projectsSummaryLine;
  final String? artStylesLine;
  final String? agentMemoryBody;
  final VoidCallback onLoadProjects;
  final VoidCallback onLoadProjectsSummary;
  final Future<void> Function() onLoadArtStyles;
  final VoidCallback onCreateEmptyProject;
  final ValueChanged<ProjectRow> onOpenProjectDetail;
  final VoidCallback onProbeAgentMemory;

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
        initialRows: artStyles ?? const <ArtStyleRow>[],
        onRefreshParent: onLoadArtStyles,
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
        initialProjects: projects ?? const <ProjectRow>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Column(
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
          loadingProjects: loadingProjects,
          loadingProjectsSummary: loadingProjectsSummary,
          loadingArtStyles: loadingArtStyles,
          creatingProject: creatingProject,
          onLoadProjects: onLoadProjects,
          onLoadProjectsSummary: onLoadProjectsSummary,
          onLoadArtStyles: () => onLoadArtStyles(),
          onOpenArtStylesWorkbench: () => _openArtStylesWorkbench(context),
          onOpenCreativeManualsWorkbench: () =>
              _openCreativeManualsWorkbench(context),
          onOpenAgentMemoryWorkbench: () => _openAgentMemoryWorkbench(context),
          onCreateEmptyProject: onCreateEmptyProject,
        ),
        const SizedBox(height: 8),
        ProjectsCompatibilityPanel(
          outlineColor: outline,
          loadingAgentMemory: loadingAgentMemory,
          onProbeAgentMemory: onProbeAgentMemory,
        ),
        ProjectsOverviewPreview(
          projectsSummaryLine: projectsSummaryLine,
          artStylesLine: artStylesLine,
          artStyles: artStyles,
          projects: projects,
          agentMemoryBody: agentMemoryBody,
          onManageArtStyles: () => _openArtStylesWorkbench(context),
          onOpenProjectDetail: onOpenProjectDetail,
        ),
      ],
    );
  }
}
