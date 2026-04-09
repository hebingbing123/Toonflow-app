import 'package:flutter/material.dart';
import '../rust_api.dart';

class ProjectsSection extends StatelessWidget {
  const ProjectsSection({
    super.key,
    required this.loadingProjects,
    required this.loadingProjectsSummary,
    required this.loadingArtStyles,
    required this.creatingProject,
    required this.loadingAgentMemory,
    required this.projects,
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

  final bool loadingProjects;
  final bool loadingProjectsSummary;
  final bool loadingArtStyles;
  final bool creatingProject;
  final bool loadingAgentMemory;
  final List<ProjectRow>? projects;
  final String? projectsSummaryLine;
  final String? artStylesLine;
  final String? agentMemoryBody;
  final VoidCallback onLoadProjects;
  final VoidCallback onLoadProjectsSummary;
  final VoidCallback onLoadArtStyles;
  final VoidCallback onCreateEmptyProject;
  final ValueChanged<ProjectRow> onOpenProjectDetail;
  final VoidCallback onProbeAgentMemory;

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
          '查看项目、摘要与美术风格，并进入项目详情继续编辑。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: (loadingProjects || creatingProject)
                  ? null
                  : onLoadProjects,
              child: Text(loadingProjects ? '加载中…' : '加载项目列表'),
            ),
            FilledButton.tonal(
              onPressed: (loadingProjectsSummary || creatingProject)
                  ? null
                  : onLoadProjectsSummary,
              child: Text(loadingProjectsSummary ? '加载中…' : '查看项目摘要'),
            ),
            FilledButton.tonal(
              onPressed: (loadingArtStyles || creatingProject)
                  ? null
                  : onLoadArtStyles,
              child: Text(loadingArtStyles ? '加载中…' : '加载美术风格'),
            ),
            FilledButton.tonal(
              onPressed: (loadingProjects || creatingProject)
                  ? null
                  : onCreateEmptyProject,
              child: Text(creatingProject ? '创建中…' : '新建空项目'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留 Agent memory 首项目查询回归入口，默认折叠',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
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
        ),
        if (projectsSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('项目摘要：$projectsSummaryLine'),
        ],
        if (artStylesLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('美术风格：$artStylesLine'),
        ],
        if (projects != null) ...[
          const SizedBox(height: 12),
          Text(
            '${projects!.length} 个项目',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...projects!.map(
            (project) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(project.name ?? '项目 #${project.legacyId}'),
              subtitle: Text('#${project.legacyId} · ${project.id}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenProjectDetail(project),
            ),
          ),
          if (agentMemoryBody != null) ...[
            const SizedBox(height: 8),
            SelectableText('项目记忆：$agentMemoryBody'),
          ],
        ],
      ],
    );
  }
}
