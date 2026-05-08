import 'package:flutter/material.dart';

import '../rust_api.dart';

/// Per-project editor / viewer ACL (`app_project_member`), managed by workspace
/// owner/admin or project owner.
class ProjectMembersPanel extends StatefulWidget {
  const ProjectMembersPanel({
    super.key,
    required this.accessToken,
    required this.projectId,
  });

  final String accessToken;
  final String projectId;

  @override
  State<ProjectMembersPanel> createState() => _ProjectMembersPanelState();
}

class _ProjectMembersPanelState extends State<ProjectMembersPanel> {
  List<ProjectMemberResponse>? _rows;
  String? _error;
  bool _loading = true;
  final _newUserIdCtrl = TextEditingController();
  String _newRole = 'viewer';
  final Map<String, String> _pendingRole = {};

  @override
  void dispose() {
    _newUserIdCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await fetchProjectMembersV1(
        widget.accessToken,
        widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _rows = list;
        _pendingRole.clear();
        for (final r in list) {
          _pendingRole[r.userId] = r.role;
        }
        _loading = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = null;
        _error = formatRustApiException(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = null;
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final raw = _newUserIdCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!_looksLikeUuid(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的用户 UUID')),
      );
      return;
    }
    try {
      await createProjectMemberV1(
        widget.accessToken,
        widget.projectId,
        userId: raw,
        role: _newRole,
      );
      if (!mounted) return;
      _newUserIdCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已添加项目成员')),
      );
      await _reload();
    } on RustApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatRustApiException(e))),
      );
    }
  }

  Future<void> _saveRow(String userId) async {
    final role = _pendingRole[userId];
    if (role == null) return;
    try {
      await patchProjectMemberV1(
        widget.accessToken,
        widget.projectId,
        userId,
        role: role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('角色已更新')),
      );
      await _reload();
    } on RustApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatRustApiException(e))),
      );
    }
  }

  Future<void> _remove(String userId) async {
    try {
      await deleteProjectMemberV1(
        widget.accessToken,
        widget.projectId,
        userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已移除')),
      );
      await _reload();
    } on RustApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatRustApiException(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('项目成员（细粒度）', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '未添加任何行时，workspace 内成员均可访问本项目；添加后仅 owner/admin、'
            '项目负责人与下列成员可访问（viewer 只读，editor 可改）。目标用户须已是 workspace 成员。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
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
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_rows != null) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newUserIdCtrl,
                    decoration: const InputDecoration(
                      labelText: '用户 UUID',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _newRole,
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('viewer')),
                    DropdownMenuItem(value: 'editor', child: Text('editor')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _newRole = v);
                  },
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _add,
                  child: const Text('添加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_rows!.isEmpty)
              Text(
                '当前无显式成员行。',
                style: theme.textTheme.bodySmall,
              )
            else
              ..._rows!.map((r) {
                final pending = _pendingRole[r.userId] ?? r.role;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          r.userId,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      DropdownButton<String>(
                        value: pending,
                        items: const [
                          DropdownMenuItem(
                            value: 'viewer',
                            child: Text('viewer'),
                          ),
                          DropdownMenuItem(
                            value: 'editor',
                            child: Text('editor'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _pendingRole[r.userId] = v);
                          }
                        },
                      ),
                      IconButton(
                        tooltip: '保存角色',
                        onPressed: pending == r.role ? null : () => _saveRow(r.userId),
                        icon: const Icon(Icons.save_outlined),
                      ),
                      IconButton(
                        tooltip: '移除',
                        onPressed: () => _remove(r.userId),
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

bool _looksLikeUuid(String s) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(s.trim());
}
