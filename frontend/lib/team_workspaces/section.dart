import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rust_api.dart';
import 'invite_deep_link.dart';

/// Team / enterprise workspace lifecycle（**W1.1–W1.6**：列表/创建/归档与恢复/配额由后端约束）。
List<WorkspaceMemberResponse> filterWorkspaceMembers(
  List<WorkspaceMemberResponse> members,
  String keyword,
) {
  final needle = keyword.trim().toLowerCase();
  if (needle.isEmpty) {
    return members;
  }
  return members
      .where(
        (m) =>
            m.userId.toLowerCase().contains(needle) ||
            m.role.toLowerCase().contains(needle),
      )
      .toList(growable: false);
}

List<WorkspaceInviteResponse> filterWorkspaceInvites(
  List<WorkspaceInviteResponse> invites,
  String keyword,
) {
  final needle = keyword.trim().toLowerCase();
  if (needle.isEmpty) {
    return invites;
  }
  return invites
      .where(
        (invite) =>
            invite.email.toLowerCase().contains(needle) ||
            invite.role.toLowerCase().contains(needle) ||
            invite.status.toLowerCase().contains(needle),
      )
      .toList(growable: false);
}

List<WorkspaceInviteResponse> filterInvitesByExpiryVisibility(
  List<WorkspaceInviteResponse> invites, {
  required bool includeExpired,
}) {
  if (includeExpired) {
    return invites;
  }
  return invites
      .where((invite) => !isWorkspaceInviteExpired(invite))
      .toList(growable: false);
}

String formatWorkspaceInviteMeta(WorkspaceInviteResponse invite) {
  final expiry = invite.expiresAt.toLocal().toIso8601String();
  final stateText = inviteStatusLabel(invite);
  return '状态: $stateText · 过期: $expiry';
}

bool isWorkspaceInviteExpired(WorkspaceInviteResponse invite) {
  return invite.expiresAt.isBefore(DateTime.now().toUtc());
}

String inviteStatusLabel(WorkspaceInviteResponse invite) {
  if (isWorkspaceInviteExpired(invite)) {
    return '已过期';
  }
  if (invite.status == 'pending') {
    return '有效';
  }
  return invite.status;
}

String buildInviteCopyText(WorkspaceInviteResponse invite) {
  return 'workspace=${invite.workspaceId}\n'
      'email=${invite.email}\n'
      'role=${invite.role}\n'
      'status=${invite.status}\n'
      'expires_at=${invite.expiresAt.toUtc().toIso8601String()}\n'
      'token=${invite.token}';
}

List<WorkspaceInviteResponse> sortWorkspaceInvitesByExpiry(
  List<WorkspaceInviteResponse> invites,
) {
  final rows = List<WorkspaceInviteResponse>.of(invites);
  rows.sort((a, b) {
    final aExpired = isWorkspaceInviteExpired(a);
    final bExpired = isWorkspaceInviteExpired(b);
    if (aExpired != bExpired) {
      return aExpired ? 1 : -1; // valid first
    }
    return a.expiresAt.compareTo(b.expiresAt);
  });
  return rows;
}

class TeamWorkspacesSection extends StatefulWidget {
  const TeamWorkspacesSection({
    super.key,
    required this.accessToken,
    this.onWorkspaceContextChanged,
    this.initialInviteToken,
  });

  final String? accessToken;
  final Future<void> Function()? onWorkspaceContextChanged;
  final String? initialInviteToken;

  @override
  State<TeamWorkspacesSection> createState() => _TeamWorkspacesSectionState();
}

class _TeamWorkspacesSectionState extends State<TeamWorkspacesSection> {
  final _nameController = TextEditingController();
  final _acceptInviteTokenController = TextEditingController();
  List<WorkspaceListItem>? _items;
  String? _error;
  bool _loading = false;
  bool _creating = false;
  bool _acceptingInvite = false;
  bool _inviteTokenFromUri = false;
  bool _includeArchived = false;
  String? _patchingWorkspaceId;
  String? _switchingWorkspaceId;

  @override
  void dispose() {
    _nameController.dispose();
    _acceptInviteTokenController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final invitePrefill = resolveWorkspaceInvitePrefill(
      initialInviteToken: widget.initialInviteToken,
      uriBase: Uri.base,
    );
    if (invitePrefill.token != null && invitePrefill.token!.isNotEmpty) {
      _acceptInviteTokenController.text = invitePrefill.token!;
      _inviteTokenFromUri = invitePrefill.tokenFromUri;
    }
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
      final rows = await fetchWorkspacesV1(
        token,
        includeArchived: _includeArchived,
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入企业空间名称')));
      return;
    }
    setState(() => _creating = true);
    try {
      await createWorkspaceV1(token, CreateWorkspaceBody(name: name));
      _nameController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已创建企业空间')));
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _acceptInvite() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final inviteToken = _acceptInviteTokenController.text.trim();
    if (inviteToken.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入邀请 token')));
      return;
    }
    setState(() => _acceptingInvite = true);
    try {
      await acceptWorkspaceInviteV1(
        token,
        AcceptWorkspaceInviteBody(token: inviteToken),
      );
      _acceptInviteTokenController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已接受邀请并加入工作区')));
      if (_inviteTokenFromUri) {
        final cleaned = removeWorkspaceInviteTokenFromUri(Uri.base);
        SystemNavigator.routeInformationUpdated(uri: cleaned);
        _inviteTokenFromUri = false;
      }
      if (widget.onWorkspaceContextChanged != null) {
        await widget.onWorkspaceContextChanged!();
      }
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('接受邀请失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _acceptingInvite = false);
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
    final memberSearchController = TextEditingController();
    final inviteSearchController = TextEditingController();
    String role = 'member';
    List<WorkspaceMemberResponse> members = <WorkspaceMemberResponse>[];
    final List<WorkspaceInviteResponse> pendingInvites =
        <WorkspaceInviteResponse>[];
    String? error;
    bool loading = true;
    bool adding = false;
    bool inviting = false;
    String? mutatingMemberUserId;
    bool leaving = false;
    bool includeExpiredInvites = false;

    Future<void> loadMembers(StateSetter setModalState) async {
      setModalState(() {
        loading = true;
        error = null;
      });
      try {
        final rows = await fetchWorkspaceMembersV1(token, row.workspace.id);
        final invites = await fetchWorkspaceInvitesV1(
          token,
          row.workspace.id,
          status: 'pending',
          limit: 50,
        );
        setModalState(() {
          members = rows;
          pendingInvites
            ..clear()
            ..addAll(invites);
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
                          DropdownMenuItem(
                            value: 'member',
                            child: Text('member'),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('admin'),
                          ),
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
                            onPressed: loading
                                ? null
                                : () => loadMembers(setModalState),
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
                                  setModalState(() {
                                    pendingInvites.insert(0, invite);
                                  });
                                  inviteEmailController.clear();
                                } catch (e) {
                                  setModalState(() => error = e.toString());
                                } finally {
                                  setModalState(() => inviting = false);
                                }
                              },
                        child: Text(inviting ? '生成邀请中…' : '生成邀请链接'),
                      ),
                      if (pendingInvites.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          'pending 邀请（本次会话）',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('显示已过期邀请'),
                          value: includeExpiredInvites,
                          onChanged: (v) =>
                              setModalState(() => includeExpiredInvites = v),
                        ),
                        TextField(
                          controller: inviteSearchController,
                          decoration: const InputDecoration(
                            labelText: '搜索邀请（邮箱 / 角色 / 状态）',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 4),
                        ...sortWorkspaceInvitesByExpiry(
                          filterInvitesByExpiryVisibility(
                            filterWorkspaceInvites(
                              pendingInvites,
                              inviteSearchController.text,
                            ),
                            includeExpired: includeExpiredInvites,
                          ),
                        ).map((invite) {
                          final label = inviteStatusLabel(invite);
                          final chipColor = label == '已过期'
                              ? Theme.of(context).colorScheme.errorContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Wrap(
                                      spacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: <Widget>[
                                        Text(
                                          '${invite.email} · ${invite.role}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        Chip(
                                          label: Text(label),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: chipColor,
                                        ),
                                      ],
                                    ),
                                    SelectableText(
                                      '${formatWorkspaceInviteMeta(invite)}\ninvite token: ${invite.token}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '复制邀请信息',
                                icon: const Icon(
                                  Icons.copy_all_outlined,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: buildInviteCopyText(invite),
                                    ),
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('已复制邀请：${invite.email}'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        }),
                      ],
                      if (error != null) ...<Widget>[
                        const SizedBox(height: 8),
                        SelectableText(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: memberSearchController,
                        decoration: const InputDecoration(
                          labelText: '搜索成员（UUID / 角色）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 8),
                      if (members.isEmpty && !loading) const Text('暂无成员（异常）。'),
                      if (loading) const LinearProgressIndicator(),
                      if (members.isNotEmpty)
                        ...filterWorkspaceMembers(
                          members,
                          memberSearchController.text,
                        ).map(
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
                                            setModalState(
                                              () => error = e.toString(),
                                            );
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
                                            setModalState(
                                              () => error = e.toString(),
                                            );
                                          } finally {
                                            setModalState(
                                              () => mutatingMemberUserId = null,
                                            );
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                  ),
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
                            if (widget.onWorkspaceContextChanged != null) {
                              await widget.onWorkspaceContextChanged!();
                            }
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
    memberSearchController.dispose();
    inviteSearchController.dispose();
  }

  Future<void> _confirmArchive(WorkspaceListItem row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('归档企业空间？'),
        content: const Text('归档后该空间将从默认列表隐藏；若其为当前工作区，将自动回到 Personal。'),
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
      await patchWorkspaceV1(token, id, PatchWorkspaceBody(archive: archive));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(archive ? '已归档' : '已恢复')));
      if (widget.onWorkspaceContextChanged != null) {
        await widget.onWorkspaceContextChanged!();
      }
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已切换到 ${row.workspace.name}')));
      if (widget.onWorkspaceContextChanged != null) {
        await widget.onWorkspaceContextChanged!();
      }
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('切换失败：$e')));
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
      return Text('登录后可管理企业工作区。', style: theme.textTheme.bodyMedium);
    }

    final items = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('团队工作区', style: theme.textTheme.titleMedium),
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
        if (shouldShowInviteTokenHint(
          tokenAutoFilledFromUri: _inviteTokenFromUri,
          tokenText: _acceptInviteTokenController.text,
        )) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '已从链接自动填入邀请 token，可直接点击“接受邀请”。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _acceptInviteTokenController,
                decoration: const InputDecoration(
                  labelText: '邀请 token（接受加入）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: _acceptingInvite ? null : _acceptInvite,
              child: Text(_acceptingInvite ? '加入中…' : '接受邀请'),
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
                        onPressed: (_loading || busy)
                            ? null
                            : () => _openMembersDialog(row),
                        child: const Text('成员'),
                      ),
                    TextButton(
                      onPressed: (_loading || busy || switching)
                          ? null
                          : () => _switchCurrentWorkspace(row),
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
                        onPressed: (_loading || busy)
                            ? null
                            : () => _confirmArchive(row),
                        child: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('归档'),
                      ),
                    if (canManage && w.archivedAt != null)
                      TextButton(
                        onPressed: (_loading || busy)
                            ? null
                            : () => _setArchive(row, false),
                        child: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
