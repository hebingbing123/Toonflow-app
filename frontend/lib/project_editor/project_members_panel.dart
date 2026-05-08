import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rust_api.dart';

/// Per-project editor / viewer ACL (`app_project_member`), managed by workspace
/// owner/admin or project owner.
class ProjectMembersPanel extends StatefulWidget {
  const ProjectMembersPanel({
    super.key,
    required this.accessToken,
    required this.projectId,
    this.workspaceId,
  });

  final String accessToken;
  final String projectId;
  final String? workspaceId;

  @override
  State<ProjectMembersPanel> createState() => _ProjectMembersPanelState();
}

class _ProjectMembersPanelState extends State<ProjectMembersPanel> {
  final _manualUserIdCtrl = TextEditingController();
  List<ProjectMemberResponse> _projectRows = const <ProjectMemberResponse>[];
  List<WorkspaceMemberResponse> _workspaceRows = const <WorkspaceMemberResponse>[];
  String? _error;
  String? _workspaceMembersError;
  bool _loading = true;
  bool _projectMembersForbidden = false;
  bool _loadingWorkspaceMembers = false;
  bool _workspaceMembersForbidden = false;
  bool _adding = false;
  String _newRole = 'viewer';
  String? _selectedWorkspaceCandidateUserId;
  final Map<String, String> _pendingRole = <String, String>{};
  final Set<String> _savingUsers = <String>{};
  final Set<String> _removingUsers = <String>{};

  @override
  void dispose() {
    _manualUserIdCtrl.dispose();
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
      _projectMembersForbidden = false;
    });

    try {
      final rows = await fetchProjectMembersV1(
        widget.accessToken,
        widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _projectRows = rows;
        _pendingRole
          ..clear()
          ..addEntries(rows.map((row) => MapEntry(row.userId, row.role)));
        _loading = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _projectRows = const <ProjectMemberResponse>[];
        _pendingRole.clear();
        _loading = false;
        if (e.statusCode == 403) {
          _projectMembersForbidden = true;
        } else {
          _error = formatRustApiException(e);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectRows = const <ProjectMemberResponse>[];
        _pendingRole.clear();
        _loading = false;
        _error = '$e';
      });
    }

    await _loadWorkspaceMembers();
  }

  Future<void> _loadWorkspaceMembers() async {
    final workspaceId = widget.workspaceId?.trim();
    if (workspaceId == null || workspaceId.isEmpty) {
      setState(() {
        _workspaceRows = const <WorkspaceMemberResponse>[];
        _workspaceMembersError = null;
        _workspaceMembersForbidden = false;
        _loadingWorkspaceMembers = false;
        _selectedWorkspaceCandidateUserId = null;
      });
      return;
    }

    setState(() {
      _loadingWorkspaceMembers = true;
      _workspaceMembersError = null;
      _workspaceMembersForbidden = false;
    });

    try {
      final rows = await fetchWorkspaceMembersV1(widget.accessToken, workspaceId);
      if (!mounted) return;
      setState(() {
        _workspaceRows = rows;
        _loadingWorkspaceMembers = false;
        _selectedWorkspaceCandidateUserId = _defaultWorkspaceCandidateUserId(rows);
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _workspaceRows = const <WorkspaceMemberResponse>[];
        _loadingWorkspaceMembers = false;
        _selectedWorkspaceCandidateUserId = null;
        if (e.statusCode == 403) {
          _workspaceMembersForbidden = true;
        } else {
          _workspaceMembersError = formatRustApiException(e);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspaceRows = const <WorkspaceMemberResponse>[];
        _loadingWorkspaceMembers = false;
        _selectedWorkspaceCandidateUserId = null;
        _workspaceMembersError = '$e';
      });
    }
  }

  String? _defaultWorkspaceCandidateUserId(List<WorkspaceMemberResponse> rows) {
    final explicitUserIds = _explicitUserIds;
    for (final row in rows) {
      if (row.role == 'member' && !explicitUserIds.contains(row.userId)) {
        return row.userId;
      }
    }
    return null;
  }

  Set<String> get _explicitUserIds =>
      _projectRows.map((row) => row.userId).toSet();

  bool get _aclEnabled => _projectRows.isNotEmpty;

  List<WorkspaceMemberResponse> get _assignableWorkspaceCandidates {
    final explicitUserIds = _explicitUserIds;
    return _workspaceRows
        .where(
          (row) => row.role == 'member' && !explicitUserIds.contains(row.userId),
        )
        .toList(growable: false);
  }

  Future<void> _addManual() async {
    final raw = _manualUserIdCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!_looksLikeUuid(raw)) {
      _showSnack('请输入有效的用户 UUID');
      return;
    }
    await _createMember(raw, role: _newRole);
  }

  Future<void> _addWorkspaceCandidate() async {
    final userId = _selectedWorkspaceCandidateUserId;
    if (userId == null || userId.isEmpty) {
      _showSnack('当前没有可直接添加的 workspace member');
      return;
    }
    await _createMember(userId, role: _newRole);
  }

  Future<void> _createMember(String userId, {required String role}) async {
    setState(() {
      _adding = true;
    });
    try {
      await createProjectMemberV1(
        widget.accessToken,
        widget.projectId,
        userId: userId,
        role: role,
      );
      if (!mounted) return;
      _manualUserIdCtrl.clear();
      _showSnack('已添加项目成员');
      await _reload();
    } on RustApiException catch (e) {
      if (!mounted) return;
      _showSnack(formatRustApiException(e));
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e');
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
        });
      }
    }
  }

  Future<void> _saveRow(String userId) async {
    final role = _pendingRole[userId];
    if (role == null) return;
    setState(() {
      _savingUsers.add(userId);
    });
    try {
      await patchProjectMemberV1(
        widget.accessToken,
        widget.projectId,
        userId,
        role: role,
      );
      if (!mounted) return;
      _showSnack('角色已更新');
      await _reload();
    } on RustApiException catch (e) {
      if (!mounted) return;
      _showSnack(formatRustApiException(e));
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e');
    } finally {
      if (mounted) {
        setState(() {
          _savingUsers.remove(userId);
        });
      }
    }
  }

  Future<void> _remove(String userId) async {
    setState(() {
      _removingUsers.add(userId);
    });
    try {
      await deleteProjectMemberV1(widget.accessToken, widget.projectId, userId);
      if (!mounted) return;
      _showSnack('已移除显式 ACL');
      await _reload();
    } on RustApiException catch (e) {
      if (!mounted) return;
      _showSnack(formatRustApiException(e));
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e');
    } finally {
      if (mounted) {
        setState(() {
          _removingUsers.remove(userId);
        });
      }
    }
  }

  void _copyUserId(String userId) {
    Clipboard.setData(ClipboardData(text: userId));
    _showSnack('已复制用户 UUID');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignableCandidates = _assignableWorkspaceCandidates;
    final selectedCandidateStillValid = assignableCandidates.any(
      (row) => row.userId == _selectedWorkspaceCandidateUserId,
    );
    if (!selectedCandidateStillValid && assignableCandidates.isNotEmpty) {
      _selectedWorkspaceCandidateUserId = assignableCandidates.first.userId;
    }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('项目成员 ACL', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      _aclEnabled
                          ? '当前项目已启用显式 ACL：普通 member 只会按 viewer / editor 行生效；workspace owner/admin 仍有天然完全权限。'
                          : '当前项目仍处于 workspace 继承模式：普通 member 默认沿用原有项目访问权限。只要新增第一条显式 ACL，项目就会切到 restricted 模式。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  _buildSummaryChip(
                    theme,
                    label: '模式',
                    value: _aclEnabled ? 'restricted' : 'inherited',
                  ),
                  _buildSummaryChip(
                    theme,
                    label: '显式成员',
                    value: '${_projectRows.length}',
                  ),
                  if (widget.workspaceId != null)
                    _buildSummaryChip(
                      theme,
                      label: '候选 workspace member',
                      value: _workspaceRows.isEmpty
                          ? (_loadingWorkspaceMembers ? '...' : '${assignableCandidates.length}')
                          : '${assignableCandidates.length}',
                    ),
                ],
              ),
            ],
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
          else if (_projectMembersForbidden)
            _buildForbiddenNotice(theme)
          else ...[
            _buildAddSection(theme, assignableCandidates),
            const SizedBox(height: 12),
            _buildExplicitMembersSection(theme),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loading || _loadingWorkspaceMembers ? null : _reload,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForbiddenNotice(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前账号不能管理项目 ACL', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '只有 workspace owner/admin 或项目 owner 可以查看和修改显式项目成员。若你只需要继续编辑其它内容，当前项目仍会按已有 workspace / project 权限正常工作。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddSection(
    ThemeData theme,
    List<WorkspaceMemberResponse> assignableCandidates,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('添加显式成员', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '优先从当前 workspace member 里挑选；如果你此刻拿不到 workspace 成员列表，也可以直接输入用户 UUID 做受控补录。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _newRole,
                  decoration: const InputDecoration(
                    labelText: '授予角色',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('viewer')),
                    DropdownMenuItem(value: 'editor', child: Text('editor')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _newRole = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingWorkspaceMembers)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('正在读取 workspace 成员...', style: theme.textTheme.bodySmall),
              ],
            )
          else if (_workspaceMembersError != null)
            Text(
              _workspaceMembersError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (_workspaceMembersForbidden)
            Text(
              '当前账号没有读取 workspace 成员列表的权限；仍可直接输入用户 UUID 做显式 ACL 管理。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else if (widget.workspaceId == null || widget.workspaceId!.trim().isEmpty)
            Text(
              '这个项目暂时没有可用的 workspace 上下文，先保留手动 UUID 入口。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            if (assignableCandidates.isEmpty)
              Text(
                '当前没有可直接添加的普通 workspace member。owner/admin 已天然拥有项目访问权限，已有显式行的成员会在下方列出。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedWorkspaceCandidateUserId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '从 workspace member 里添加',
                        isDense: true,
                      ),
                      items: assignableCandidates
                          .map(
                            (row) => DropdownMenuItem<String>(
                              value: row.userId,
                              child: Text(_shortUserIdWithRole(row.userId, row.role)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _adding
                          ? null
                          : (value) {
                              setState(() {
                                _selectedWorkspaceCandidateUserId = value;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _adding ? null : _addWorkspaceCandidate,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('添加'),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualUserIdCtrl,
                  decoration: const InputDecoration(
                    labelText: '手动输入用户 UUID',
                    hintText: '00000000-0000-0000-0000-000000000000',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _adding ? null : _addManual,
                child: const Text('按 UUID 添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExplicitMembersSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('显式 ACL 行', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            _projectRows.isEmpty
                ? '当前还没有显式项目成员。项目仍按 workspace 继承模式工作。'
                : '这些行是当前项目真正启用的 viewer/editor 规则。移除最后一行后，项目会回到 inherited 模式。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (_projectRows.isEmpty)
            Text('无显式 ACL 行', style: theme.textTheme.bodySmall)
          else
            ..._projectRows.map((row) => _buildExplicitMemberRow(theme, row)),
        ],
      ),
    );
  }

  Widget _buildExplicitMemberRow(ThemeData theme, ProjectMemberResponse row) {
    final pendingRole = _pendingRole[row.userId] ?? row.role;
    final workspaceRole = _workspaceRows
        .where((candidate) => candidate.userId == row.userId)
        .map((candidate) => candidate.role)
        .cast<String?>()
        .firstOrNull;
    final saving = _savingUsers.contains(row.userId);
    final removing = _removingUsers.contains(row.userId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    row.userId,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: '复制用户 UUID',
                  onPressed: () => _copyUserId(row.userId),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag(theme, '显式角色', row.role),
                if (workspaceRole != null)
                  _buildTag(theme, 'workspace 角色', workspaceRole),
                _buildTag(
                  theme,
                  '更新时间',
                  _formatShortDateTime(row.updatedAt),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: pendingRole,
                    decoration: const InputDecoration(
                      labelText: '更新角色',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'viewer', child: Text('viewer')),
                      DropdownMenuItem(value: 'editor', child: Text('editor')),
                    ],
                    onChanged: saving || removing
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _pendingRole[row.userId] = value;
                              });
                            }
                          },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '保存角色',
                  onPressed: saving || removing || pendingRole == row.role
                      ? null
                      : () => _saveRow(row.userId),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                ),
                IconButton(
                  tooltip: '移除显式 ACL',
                  onPressed: saving || removing ? null : () => _remove(row.userId),
                  icon: removing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(
    ThemeData theme, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelSmall,
      ),
    );
  }

  String _shortUserIdWithRole(String userId, String role) {
    final trimmed = userId.trim();
    if (trimmed.length <= 18) {
      return '$trimmed · $role';
    }
    return '${trimmed.substring(0, 8)}...${trimmed.substring(trimmed.length - 6)} · $role';
  }

  String _formatShortDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

bool _looksLikeUuid(String s) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(s.trim());
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
