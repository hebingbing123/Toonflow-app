import 'package:flutter/material.dart';

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
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _rows.clear();
        _hasMore = false;
        _loading = false;
        _error = formatRustApiException(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows.clear();
        _hasMore = false;
        _loading = false;
        _error = '$e';
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
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = formatRustApiException(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            projectAuditActionLabel(row.action),
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
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('项目活动记录', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      '聚焦项目配置与 ACL 变更，方便回答“谁改了这个项目”。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _actionFilter ?? '',
                  decoration: const InputDecoration(
                    labelText: '动作过滤',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem<String>(value: '', child: Text('全部')),
                    DropdownMenuItem<String>(
                      value: 'project_updated',
                      child: Text('项目修改'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'project_member_added',
                      child: Text('添加 ACL'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'project_member_role_changed',
                      child: Text('角色调整'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'project_member_removed',
                      child: Text('移除 ACL'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'project_created',
                      child: Text('项目创建'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'project_deleted',
                      child: Text('项目删除'),
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
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '搜索 actor / target / 字段 / 项目名',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
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
            Text(
              '当前没有可显示的项目活动记录。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...filtered.map(
              (row) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(projectAuditActionLabel(row.action)),
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
                  label: const Text('加载更多'),
                ),
              TextButton.icon(
                onPressed: _loading || _loadingMore ? null : _reload,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String projectAuditActionLabel(String action) {
  switch (action) {
    case 'project_created':
      return '创建项目';
    case 'project_updated':
      return '修改项目';
    case 'project_deleted':
      return '删除项目';
    case 'project_member_added':
      return '新增项目 ACL';
    case 'project_member_role_changed':
      return '调整项目 ACL';
    case 'project_member_removed':
      return '移除项目 ACL';
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
