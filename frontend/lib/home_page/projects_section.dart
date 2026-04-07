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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Projects (RLS + Postgres)',
          style: Theme.of(context).textTheme.titleSmall,
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
              child: Text(loadingProjects ? '加载中…' : 'GET /api/v1/projects'),
            ),
            FilledButton.tonal(
              onPressed: (loadingProjectsSummary || creatingProject)
                  ? null
                  : onLoadProjectsSummary,
              child: Text(
                loadingProjectsSummary ? '加载中…' : 'GET …/projects/summary',
              ),
            ),
            FilledButton.tonal(
              onPressed: (loadingArtStyles || creatingProject)
                  ? null
                  : onLoadArtStyles,
              child: Text(
                loadingArtStyles ? '加载中…' : 'GET …/art-styles + CRUD 探针',
              ),
            ),
            FilledButton.tonal(
              onPressed: (loadingProjects || creatingProject)
                  ? null
                  : onCreateEmptyProject,
              child: Text(creatingProject ? '创建中…' : 'POST /api/v1/projects'),
            ),
          ],
        ),
        if (projectsSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('summary: $projectsSummaryLine'),
        ],
        if (artStylesLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('art-styles: $artStylesLine'),
        ],
        if (projects != null) ...[
          const SizedBox(height: 12),
          Text(
            '${projects!.length} project(s)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...projects!.map(
            (project) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(project.name ?? 'legacy #${project.legacyId}'),
              subtitle: Text('legacy_id=${project.legacyId} · ${project.id}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenProjectDetail(project),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: loadingAgentMemory ? null : onProbeAgentMemory,
            child: Text(
              loadingAgentMemory
                  ? '请求中…'
                  : 'POST /api/v1/agents/memory/query (first project)',
            ),
          ),
          if (agentMemoryBody != null) ...[
            const SizedBox(height: 8),
            SelectableText('agent memory: $agentMemoryBody'),
          ],
        ],
      ],
    );
  }
}
