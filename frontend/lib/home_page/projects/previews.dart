import 'package:flutter/material.dart';

import '../../rust_api.dart';

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
        Text('${artStyles.length} 条画风', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        ...artStyles.take(5).map(
          (style) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(style.name),
            subtitle: Text(
              '#${style.legacyId}'
              '${(style.label ?? '').isEmpty ? '' : ' · ${style.label}'}',
            ),
            trailing: TextButton(onPressed: onManage, child: const Text('管理')),
          ),
        ),
      ],
    );
  }
}

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
        Text('${projects.length} 个项目', style: Theme.of(context).textTheme.labelLarge),
        ...projects.map(
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
    );
  }
}
