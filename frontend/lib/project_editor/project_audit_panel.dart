import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_collapsible_filter_panel.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_filter_row.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../l10n/app_localizations.dart';
import '../rust_api.dart';

class ProjectAuditPanel extends StatefulWidget {
  const ProjectAuditPanel({
    super.key,
    required this.accessToken,
    required this.projectId,
  });

  final String accessToken;
  final String projectId;

  @override
  State<ProjectAuditPanel> createState() => _ProjectAuditPanelState();
}

class _ProjectAuditPanelState extends State<ProjectAuditPanel> {
  final _searchCtrl = TextEditingController();
  final List<ProjectAuditResponse> _rows = <ProjectAuditResponse>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  String? _actionFilter;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await fetchProjectAuditV1(
        widget.accessToken,
        widget.projectId,
        action: _actionFilter,
      );
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(page.items);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows.clear();
        _hasMore = false;
        _loading = false;
        _error = describeUserVisibleApiErrorResolved(context, e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final page = await fetchProjectAuditV1(
        widget.accessToken,
        widget.projectId,
        action: _actionFilter,
        offset: _rows.length,
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.items);
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = describeUserVisibleApiErrorResolved(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final needle = _searchCtrl.text.trim().toLowerCase();
    final filtered = _rows
        .where((row) {
          if (needle.isEmpty) return true;
          final changedFields =
              (row.details['changed_fields'] as List<dynamic>? ??
                      const <dynamic>[])
                  .join(' ');
          final haystack = <String>[
            row.action,
            projectAuditActionLabel(l10n, row.action),
            row.actorUserId,
            row.targetUserId ?? '',
            '${row.details['role'] ?? ''}',
            '${row.details['previous_role'] ?? ''}',
            '${row.details['project_name'] ?? row.details['project_name_after'] ?? ''}',
            changedFields,
          ].join(' ').toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: studioPanelBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.projectEditorAuditTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.projectEditorAuditSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          StudioCollapsibleFilterPanel(
            subtitle: _searchCtrl.text.trim().isEmpty
                ? null
                : '${l10n.projectEditorAuditSearchLabel}: ${_searchCtrl.text.trim()}',
            child: StudioFilterRow(
              wideLayout: StudioFilterWideLayout.toolbarRow,
              wideBreakpoint: 640,
              children: <Widget>[
                SizedBox(
                  width: 200,
                  child: StudioDropdownButtonFormField<String>(
                    initialValue: _actionFilter ?? '',
                    decoration: InputDecoration(
                      labelText: l10n.projectEditorAuditActionFilterLabel,
                      isDense: true,
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text(l10n.projectEditorAuditActionAll),
                      ),
                      DropdownMenuItem<String>(
                        value: 'project_updated',
                        child: Text(l10n.projectEditorAuditActionProjectUpdated),
                      ),
                      DropdownMenuItem<String>(
                        value: 'project_member_added',
                        child: Text(l10n.projectEditorAuditActionMemberAdded),
                      ),
                      DropdownMenuItem<String>(
                        value: 'project_member_role_changed',
                        child: Text(
                          l10n.projectEditorAuditActionMemberRoleChanged,
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: 'project_member_removed',
                        child: Text(l10n.projectEditorAuditActionMemberRemoved),
                      ),
                      DropdownMenuItem<String>(
                        value: 'project_created',
                        child: Text(l10n.projectEditorAuditActionProjectCreated),
                      ),
                      DropdownMenuItem<String>(
                        value: 'project_deleted',
                        child: Text(l10n.projectEditorAuditActionProjectDeleted),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _actionFilter = (value == null || value.isEmpty)
                            ? null
                            : value;
                      });
                      _reload();
                    },
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.projectEditorAuditSearchLabel,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            StudioEmptyState.emptyData(
              title: l10n.projectEditorAuditEmpty,
              icon: Icons.fact_check_outlined,
            )
          else
            ...filtered.map(
              (row) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(projectAuditActionLabel(l10n, row.action)),
                subtitle: Text(
                  '${row.createdAt.toLocal().toIso8601String()}\n${buildProjectAuditSummary(row)}',
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_hasMore)
                TextButton.icon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more, size: 18),
                  label: Text(l10n.projectEditorAuditLoadMore),
                ),
              TextButton.icon(
                onPressed: _loading || _loadingMore ? null : _reload,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.projectEditorAuditRefresh),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String projectAuditActionLabel(AppLocalizations l10n, String action) {
  switch (action) {
    case 'project_created':
      return l10n.projectEditorAuditActionProjectCreated;
    case 'project_updated':
      return l10n.projectEditorAuditActionProjectUpdated;
    case 'project_deleted':
      return l10n.projectEditorAuditActionProjectDeleted;
    case 'project_member_added':
      return l10n.projectEditorAuditActionMemberAdded;
    case 'project_member_role_changed':
      return l10n.projectEditorAuditActionMemberRoleChanged;
    case 'project_member_removed':
      return l10n.projectEditorAuditActionMemberRemoved;
    default:
      return action;
  }
}

String buildProjectAuditSummary(ProjectAuditResponse audit) {
  final parts = <String>[
    'actor=${audit.actorUserId}',
    if (audit.targetUserId != null) 'target=${audit.targetUserId}',
  ];
  final role = audit.details['role'];
  if (role is String && role.isNotEmpty) {
    parts.add('role=$role');
  }
  final previousRole = audit.details['previous_role'];
  if (previousRole is String && previousRole.isNotEmpty) {
    parts.add('previous=$previousRole');
  }
  final changedFields = audit.details['changed_fields'] as List<dynamic>?;
  if (changedFields != null && changedFields.isNotEmpty) {
    parts.add('fields=${changedFields.join(",")}');
  }
  final projectName =
      audit.details['project_name'] ??
      audit.details['project_name_after'] ??
      audit.details['project_name_before'];
  if (projectName is String && projectName.isNotEmpty) {
    parts.add('project=$projectName');
  }
  final numericId = audit.details['project_numeric_id'];
  if (numericId != null) {
    parts.add('numeric=$numericId');
  }
  return parts.join(' · ');
}
