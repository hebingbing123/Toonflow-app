import 'package:flutter/material.dart';

class WorkspaceContextView extends StatelessWidget {
  const WorkspaceContextView({
    super.key,
    required this.loading,
    this.workspaceName,
    this.workspaceType,
    this.projectLabel,
  });

  final bool loading;
  final String? workspaceName;
  final String? workspaceType;
  final String? projectLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspaceLine = loading
        ? 'Loading workspace...'
        : (workspaceName?.trim().isNotEmpty == true
              ? workspaceName!.trim()
              : 'No workspace');
    final scopeLine = projectLabel?.trim().isNotEmpty == true
        ? projectLabel!.trim()
        : 'No project selected';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              const Icon(Icons.workspaces_outline, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      workspaceLine,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(scopeLine, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (workspaceType?.trim().isNotEmpty == true) ...<Widget>[
                const SizedBox(width: 12),
                Chip(
                  label: Text(workspaceType!.trim()),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
