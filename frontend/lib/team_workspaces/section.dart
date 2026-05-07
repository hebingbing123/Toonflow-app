import 'package:flutter/material.dart';

import '../rust_api.dart';

/// Team / enterprise workspace lifecycle（**W1.1–W1.6**：列表/创建/归档与恢复/配额由后端约束）。
class TeamWorkspacesSection extends StatefulWidget {
  const TeamWorkspacesSection({super.key, required this.accessToken});

  final String? accessToken;

  @override
  State<TeamWorkspacesSection> createState() => _TeamWorkspacesSectionState();
}

class _TeamWorkspacesSectionState extends State<TeamWorkspacesSection> {
  final _nameController = TextEditingController();
  List<WorkspaceListItem>? _items;
  String? _error;
  bool _loading = false;
  bool _creating = false;
  bool _includeArchived = false;
  String? _patchingWorkspaceId;
  String? _switchingWorkspaceId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final token = widget.accessToken;
    if (token != null && token.isNotEmpty) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant TeamWorkspacesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final token = widget.accessToken;
    final oldToken = oldWidget.accessToken;
    if (token != oldToken) {
      if (token == null || token.isEmpty) {
        setState(() {
          _items = null;
          _error = null;
          _loading = false;
        });
      } else {
        _load();
      }
    }
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await fetchWorkspacesV1(token, includeArchived: _includeArchived);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入企业空间名称')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      await createWorkspaceV1(token, CreateWorkspaceBody(name: name));
      _nameController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已创建企业空间')),
      );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  bool _canArchiveOrRestore(WorkspaceListItem row) {
    final w = row.workspace;
    if (w.workspaceType != 'enterprise') {
      return false;
    }
    return row.role == 'owner' || row.role == 'admin';
  }

  Future<void> _openMembersDialog(WorkspaceListItem row) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final userIdController = TextEditingController();
    final inviteEmailController = TextEditingController();
    String role = 'member';
    List<WorkspaceMemberResponse> members = <WorkspaceMemberResponse>[];
    WorkspaceInviteResponse? latestInvite;
    String? error;
    bool loading = true;
    bool adding = false;
    bool inviting = false;
    String? mutatingMemberUserId;
    bool leaving = false;

    Future<void> loadMembers(StateSetter setModalState) async {
      setModalState(() {
        loading = true;
        error = null;
      });
      try {
        final rows = await fetchWorkspaceMembersV1(token, row.workspace.id);
        setModalState(() {
          members = rows;
          loading = false;
        });
      } catch (e) {
        setModalState(() {
          error = e.toString();
          loading = false;
        });
      }
    }

    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading && members.isEmpty && error == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadMembers(setModalState);
              });
            }
            return AlertDialog(
              title: Text('成员管理 · ${row.workspace.name}'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: userIdController,
                        decoration: const InputDecoration(
                          labelText: '用户 UUID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: '角色',
                          border: OutlineInputBorder(),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'member', child: Text('member')),
                          DropdownMenuItem(value: 'admin', child: Text('admin')),
                        ],
                        onChanged: adding
                            ? null
                            : (v) => setModalState(() => role = v ?? 'member'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          FilledButton(
                            onPressed: adding
                                ? null
                                : () async {
                                    final userId = userIdController.text.trim();
                                    if (userId.isEmpty) {
                                      setModalState(() => error = '请输入用户 UUID');
                                      return;
                                    }
                                    setModalState(() {
                                      adding = true;
                                      error = null;
                                    });
                                    try {
                                      await addWorkspaceMemberV1(
                                        token,
                                        row.workspace.id,
                                        AddWorkspaceMemberBody(
                                          userId: userId,
                                          role: role,
                                        ),
                                      );
                                      userIdController.clear();
                                      await loadMembers(setModalState);
                                    } catch (e) {
                                      setModalState(() => error = e.toString());
                                    } finally {
                                      setModalState(() => adding = false);
                                    }
                                  },
                            child: Text(adding ? '添加中…' : '添加成员'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: loading ? null : () => loadMembers(setModalState),
                            child: const Text('刷新'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: inviteEmailController,
                        decoration: const InputDecoration(
                          labelText: '邀请邮箱',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: inviting
                            ? null
                            : () async {
                                final email = inviteEmailController.text.trim();
                                if (email.isEmpty) {
                                  setModalState(() => error = '请输入邀请邮箱');
                                  return;
                                }
                                setModalState(() {
                                  inviting = true;
                                  error = null;
                                });
                                try {
                                  final invite = await createWorkspaceInviteV1(
                                    token,
                                    row.workspace.id,
                                    CreateWorkspaceInviteBody(
                                      email: email,
                                      role: role,
                                    ),
                                  );
                                  setModalState(() => latestInvite = invite);
                                  inviteEmailController.clear();
                                } catch (e) {
                                  setModalState(() => error = e.toString());
                                } finally {
                                  setModalState(() => inviting = false);
                                }
                              },
                        child: Text(inviting ? '生成邀请中…' : '生成邀请链接'),
                      ),
                      if (latestInvite != null) ...<Widget>[
                        const SizedBox(height: 8),
                        SelectableText(
                          'invite token: ${latestInvite!.token}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (error != null) ...<Widget>[
                        const SizedBox(height: 8),
                        SelectableText(
                          error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (members.isEmpty && !loading)
                        const Text('暂无成员（异常）。'),
                      if (loading) const LinearProgressIndicator(),
                      if (members.isNotEmpty)
                        ...members.map(
                          (m) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.userId),
                            subtitle: Text(m.role),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                DropdownButton<String>(
                                  value: m.role,
                                  items: const <DropdownMenuItem<String>>[
                                    DropdownMenuItem(
                                      value: 'member',
                                      child: Text('member'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'admin',
                                      child: Text('admin'),
                                    ),
                                  ],
                                  onChanged: mutatingMemberUserId != null
                                      ? null
                                      : (v) async {
                                          if (v == null || v == m.role) {
                                            return;
                                          }
                                          setModalState(() {
                                            mutatingMemberUserId = m.userId;
                                            error = null;
                                          });
                                          try {
                                            await patchWorkspaceMemberV1(
                                              token,
                                              row.workspace.id,
                                              m.userId,
                                              body: PatchWorkspaceMemberBody(
                                                role: v,
                                              ),
                                            );
                                            await loadMembers(setModalState);
                                          } catch (e) {
                                            setModalState(() => error = e.toString());
                                          } finally {
                                            setModalState(
                                              () => mutatingMemberUserId = null,
                                            );
                                          }
                                        },
                                ),
                                IconButton(
                                  tooltip: '移除成员',
                                  onPressed: mutatingMemberUserId != null
                                      ? null
                                      : () async {
                                          setModalState(() {
                                            mutatingMemberUserId = m.userId;
                                            error = null;
                                          });
                                          try {
                                            await removeWorkspaceMemberV1(
                                              token,
                                              row.workspace.id,
                                              m.userId,
                                            );
                                            await loadMembers(setModalState);
                                          } catch (e) {
                                            setModalState(() => error = e.toString());
                                          } finally {
                                            setModalState(
                                              () => mutatingMemberUserId = null,
                                            );
                                          }
                                        },
                                  icon: const Icon(Icons.person_remove_outlined),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: leaving
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          final messenger = ScaffoldMessenger.of(context);
                          setModalState(() {
                            leaving = true;
                            error = null;
                          });
                          try {
                            await leaveWorkspaceV1(token, row.workspace.id);
                            if (!mounted) {
                              return;
                            }
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('已退出该空间')),
                            );
                            await _load();
                          } catch (e) {
                            setModalState(() {
                              error = e.toString();
                              leaving = false;
                            });
                          }
                        },
                  child: Text(leaving ? '退出中…' : '退出该空间'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
    userIdController.dispose();
    inviteEmailController.dispose();
  }

  Future<void> _confirmArchive(WorkspaceListItem row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('归档企业空间？'),
        content: const Text(
          '归档后该空间将从默认列表隐藏；若其为当前工作区，将自动回到 Personal。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('归档'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _setArchive(row, true);
    }
  }

  Future<void> _setArchive(WorkspaceListItem row, bool archive) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final id = row.workspace.id;
    setState(() => _patchingWorkspaceId = id);
    try {
      await patchWorkspaceV1(
        token,
        id,
        PatchWorkspaceBody(archive: archive),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(archive ? '已归档' : '已恢复')),
      );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _patchingWorkspaceId = null);
      }
    }
  }

  Future<void> _switchCurrentWorkspace(WorkspaceListItem row) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final id = row.workspace.id;
    setState(() => _switchingWorkspaceId = id);
    try {
      await patchCurrentWorkspaceV1(
        token,
        PatchCurrentWorkspaceBody(workspaceId: id),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到 ${row.workspace.name}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _switchingWorkspaceId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.accessToken;
    final theme = Theme.of(context);
    if (token == null || token.isEmpty) {
      return Text(
        '登录后可管理企业工作区。',
        style: theme.textTheme.bodyMedium,
      );
    }

    final items = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '团队工作区',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '列出你可访问的空间（含 Personal），创建 enterprise 空间；owner/admin 可归档或恢复企业空间。',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '企业空间名称',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _creating ? null : _create,
              child: Text(_creating ? '创建中…' : '创建'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('显示已归档企业空间'),
          value: _includeArchived,
          onChanged: _loading
              ? null
              : (bool v) {
                  setState(() => _includeArchived = v);
                  _load();
                },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_loading ? '加载中…' : '刷新列表'),
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          SelectableText(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        if (items == null && !_loading)
          Text('尚无列表数据；点「刷新列表」。', style: theme.textTheme.bodySmall),
        if (items != null && items.isEmpty)
          Text('暂无空间（异常）；通常至少有 Personal。', style: theme.textTheme.bodySmall),
        if (items != null && items.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = items[index];
              final w = row.workspace;
              final busy = _patchingWorkspaceId == w.id;
              final switching = _switchingWorkspaceId == w.id;
              final canManage = _canArchiveOrRestore(row);
              return ListTile(
                dense: true,
                title: Text(w.name),
                subtitle: Text(
                  '${w.workspaceType} · ${row.role}'
                  '${w.archivedAt != null ? ' · 已归档' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (canManage)
                      TextButton(
                        onPressed:
                            (_loading || busy) ? null : () => _openMembersDialog(row),
                        child: const Text('成员'),
                      ),
                    TextButton(
                      onPressed:
                          (_loading || busy || switching) ? null : () => _switchCurrentWorkspace(row),
                      child: switching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('切换到此'),
                    ),
                    if (canManage && w.archivedAt == null)
                      TextButton(
                        onPressed: (_loading || busy) ? null : () => _confirmArchive(row),
                        child: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('归档'),
                      ),
                    if (canManage && w.archivedAt != null)
                      TextButton(
                        onPressed: (_loading || busy) ? null : () => _setArchive(row, false),
                        child: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('恢复'),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
