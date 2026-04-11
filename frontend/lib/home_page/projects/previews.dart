import 'package:flutter/material.dart';

import '../../rust_api.dart';

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: (loadingProjects || creatingProject) ? null : onLoadProjects,
          child: Text(loadingProjects ? '加载中…' : '加载项目列表'),
        ),
        FilledButton.tonal(
          onPressed:
              (loadingProjectsSummary || creatingProject)
              ? null
              : onLoadProjectsSummary,
          child: Text(loadingProjectsSummary ? '加载中…' : '查看项目摘要'),
        ),
        FilledButton.tonal(
          onPressed: (loadingArtStyles || creatingProject) ? null : onLoadArtStyles,
          child: Text(loadingArtStyles ? '加载中…' : '加载美术风格'),
        ),
        FilledButton.tonal(
          onPressed: creatingProject ? null : onOpenArtStylesWorkbench,
          child: const Text('打开画风工作台'),
        ),
        FilledButton.tonal(
          onPressed: creatingProject ? null : onOpenCreativeManualsWorkbench,
          child: const Text('打开创作手册工作台'),
        ),
        FilledButton.tonal(
          onPressed: creatingProject ? null : onOpenAgentMemoryWorkbench,
          child: const Text('打开记忆工作台'),
        ),
        FilledButton.tonal(
          onPressed: (loadingProjects || creatingProject)
              ? null
              : onCreateEmptyProject,
          child: Text(creatingProject ? '创建中…' : '新建空项目'),
        ),
      ],
    );
  }
}

/// Wraps the legacy agent-memory probe used as a regression checkpoint.
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
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('兼容性检查'),
      subtitle: Text(
        '保留首项目 Agent memory probe 作为回归入口，默认折叠',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: outlineColor),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: loadingAgentMemory ? null : onProbeAgentMemory,
            child: Text(loadingAgentMemory ? '请求中…' : '查询首个项目记忆'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (projectsSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('项目摘要：$projectsSummaryLine'),
        ],
        if (artStylesLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('美术风格：$artStylesLine'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          '${artStyles.length} 条画风',
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
            trailing: TextButton(onPressed: onManage, child: const Text('管理')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          '${projects.length} 个项目',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        ...projects.map(
          (project) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(project.name ?? '项目 #${project.numericId}'),
            subtitle: Text('#${project.numericId} · ${project.id}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpenProjectDetail(project),
          ),
        ),
        if (agentMemoryBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('项目记忆：$agentMemoryBody'),
        ],
      ],
    );
  }
}
