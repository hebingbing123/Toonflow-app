import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'invite_deep_link.dart';
import 'strings.dart';

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
  if (invite.status == 'revoked') {
    return '已撤销';
  }
  if (isWorkspaceInviteExpired(invite)) {
    return '已过期';
  }
  if (invite.status == 'pending') {
    return '有效';
  }
  if (invite.status == 'accepted') {
    return '已接受';
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

String workspaceAuditActionLabel(String action) {
  switch (action) {
    case 'workspace_member_upserted':
      return '成员已添加或更新';
    case 'workspace_member_role_changed':
      return '成员角色已变更';
    case 'workspace_member_removed':
      return '成员已移除';
    case 'workspace_member_left':
      return '成员主动离开';
    case 'workspace_owner_transferred':
      return 'owner 已转让';
    case 'workspace_invite_created':
      return '邀请已创建';
    case 'workspace_invite_resent':
      return '邀请已重发';
    case 'workspace_invite_revoked':
      return '邀请已撤销';
    case 'workspace_invite_accepted':
      return '邀请已接受';
    default:
      return action;
  }
}

String buildWorkspaceAuditSummary(WorkspaceAuditResponse audit) {
  final parts = <String>[
    'actor=${audit.actorUserId}',
    if (audit.targetUserId != null) 'target=${audit.targetUserId}',
  ];
  final role = audit.details['role'];
  if (role is String && role.isNotEmpty) {
    parts.add('role=$role');
  }
  final email = audit.details['email'];
  if (email is String && email.isNotEmpty) {
    parts.add('email=$email');
  }
  final inviteId = audit.details['invite_id'];
  if (inviteId is String && inviteId.isNotEmpty) {
    parts.add('invite=$inviteId');
  }
  final previousOwner = audit.details['previous_owner_user_id'];
  if (previousOwner is String && previousOwner.isNotEmpty) {
    parts.add('previous_owner=$previousOwner');
  }
  final newOwner = audit.details['new_owner_user_id'];
  if (newOwner is String && newOwner.isNotEmpty) {
    parts.add('new_owner=$newOwner');
  }
  return parts.join(' · ');
}

bool hasActiveEnterpriseWorkspace(List<WorkspaceListItem> items) {
  return items.any(
    (row) =>
        row.workspace.workspaceType == 'enterprise' &&
        row.workspace.archivedAt == null,
  );
}

bool isCurrentWorkspaceRow(WorkspaceListItem row, String? currentWorkspaceId) {
  final current = currentWorkspaceId?.trim();
  if (current == null || current.isEmpty) {
    return false;
  }
  return row.workspace.id == current;
}

List<WorkspaceInviteResponse> paginateWorkspaceInvites(
  List<WorkspaceInviteResponse> invites, {
  required int pageIndex,
  required int pageSize,
}) {
  if (invites.isEmpty || pageSize <= 0 || pageIndex < 0) {
    return const <WorkspaceInviteResponse>[];
  }
  final start = pageIndex * pageSize;
  if (start >= invites.length) {
    return const <WorkspaceInviteResponse>[];
  }
  final end = (start + pageSize).clamp(0, invites.length);
  return invites.sublist(start, end);
}

int workspaceInvitePageCount(
  List<WorkspaceInviteResponse> invites, {
  required int pageSize,
}) {
  if (invites.isEmpty || pageSize <= 0) {
    return 0;
  }
  return ((invites.length - 1) ~/ pageSize) + 1;
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
    this.currentWorkspaceId,
  });

  final String? accessToken;
  final Future<void> Function()? onWorkspaceContextChanged;
  final String? initialInviteToken;
  final String? currentWorkspaceId;

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
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      showRustApiErrorSnackBar(e);
      setState(() {
        _error = describeRustApiError(e);
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
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：${describeRustApiError(e)}')),
      );
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
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('接受邀请失败：${describeRustApiError(e)}')),
      );
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
    final auditSearchController = TextEditingController();
    String role = 'member';
    List<WorkspaceMemberResponse> members = <WorkspaceMemberResponse>[];
    final List<WorkspaceInviteResponse> pendingInvites =
        <WorkspaceInviteResponse>[];
    final List<WorkspaceAuditResponse> auditRows = <WorkspaceAuditResponse>[];
    String? error;
    bool loading = true;
    bool adding = false;
    bool inviting = false;
    String? mutatingMemberUserId;
    String? inviteActionBusyId;
    bool leaving = false;
    bool includeExpiredInvites = false;
    bool includeRevokedInvites = false;
    int inviteOffset = 0;
    bool inviteHasMore = false;
    bool loadingMoreInvites = false;
    int auditOffset = 0;
    bool auditHasMore = false;
    bool loadingMoreAudit = false;
    String currentOwnerUserId = row.workspace.ownerUserId;
    String currentWorkspaceRole = row.role;
    final showWorkspaceOpsStats = kInternalOpsToken.trim().isNotEmpty;
    WorkspaceStatsResponse? workspaceStats;
    String? workspaceStatsError;
    bool loadingWorkspaceStats = false;

    Future<bool> confirmOwnerTransfer(WorkspaceMemberResponse member) async {
      return await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('转让 owner'),
                content: SelectableText(
                  '将把 ${row.workspace.name} 的主 owner 从 $currentOwnerUserId\n'
                  '转给 ${member.userId}。\n\n'
                  '提交后当前主 owner 会自动降为 admin，目标成员会升为 owner。',
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认转让'),
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    Future<void> loadAuditPage(
      StateSetter setModalState, {
      bool append = false,
    }) async {
      if (!append) {
        setModalState(() {
          auditOffset = 0;
          auditHasMore = false;
        });
      } else {
        setModalState(() => loadingMoreAudit = true);
      }
      try {
        final page = await fetchWorkspaceAuditPageV1(
          token,
          row.workspace.id,
          limit: 30,
          offset: append ? auditOffset : 0,
        );
        setModalState(() {
          if (!append) {
            auditRows
              ..clear()
              ..addAll(page.items);
          } else {
            auditRows.addAll(page.items);
          }
          auditHasMore = page.hasMore;
          auditOffset = append
              ? auditOffset + page.items.length
              : page.items.length;
          loadingMoreAudit = false;
        });
      } catch (e) {
        setModalState(() {
          error = describeRustApiError(e);
          loadingMoreAudit = false;
        });
      }
    }

    Future<void> loadWorkspaceStats(
      StateSetter setModalState, {
      bool silent = false,
    }) async {
      if (!showWorkspaceOpsStats) {
        return;
      }
      setModalState(() {
        if (!silent) {
          loadingWorkspaceStats = true;
        }
        workspaceStatsError = null;
      });
      try {
        final stats = await fetchWorkspaceStatsV1(
          row.workspace.id,
          internalOpsToken: kInternalOpsToken,
        );
        setModalState(() {
          workspaceStats = stats;
          loadingWorkspaceStats = false;
        });
      } catch (e) {
        setModalState(() {
          workspaceStatsError = describeRustApiError(e);
          loadingWorkspaceStats = false;
        });
      }
    }

    Future<void> loadMembers(StateSetter setModalState) async {
      setModalState(() {
        loading = true;
        error = null;
        inviteOffset = 0;
        inviteHasMore = false;
        auditOffset = 0;
        auditHasMore = false;
      });
      try {
        final rows = await fetchWorkspaceMembersV1(token, row.workspace.id);
        final invitesPage = await fetchWorkspaceInvitesPageV1(
          token,
          row.workspace.id,
          limit: 50,
          offset: 0,
          includeRevoked: includeRevokedInvites,
        );
        final auditPage =
            (currentWorkspaceRole == 'owner' || currentWorkspaceRole == 'admin')
            ? await fetchWorkspaceAuditPageV1(
                token,
                row.workspace.id,
                limit: 30,
                offset: 0,
              )
            : const WorkspaceAuditListEnvelope(
                items: <WorkspaceAuditResponse>[],
                hasMore: false,
              );
        setModalState(() {
          members = rows;
          pendingInvites
            ..clear()
            ..addAll(invitesPage.items);
          auditRows
            ..clear()
            ..addAll(auditPage.items);
          inviteHasMore = invitesPage.hasMore;
          inviteOffset = invitesPage.items.length;
          auditHasMore = auditPage.hasMore;
          auditOffset = auditPage.items.length;
          loading = false;
          loadingMoreInvites = false;
          loadingMoreAudit = false;
        });
        await loadWorkspaceStats(setModalState, silent: true);
      } catch (e) {
        setModalState(() {
          error = describeRustApiError(e);
          loading = false;
          loadingMoreInvites = false;
          loadingMoreAudit = false;
        });
      }
    }

    Future<void> loadMoreInvites(StateSetter setModalState) async {
      setModalState(() => loadingMoreInvites = true);
      try {
        final page = await fetchWorkspaceInvitesPageV1(
          token,
          row.workspace.id,
          limit: 50,
          offset: inviteOffset,
          includeRevoked: includeRevokedInvites,
        );
        setModalState(() {
          pendingInvites.addAll(page.items);
          inviteHasMore = page.hasMore;
          inviteOffset += page.items.length;
          loadingMoreInvites = false;
        });
      } catch (e) {
        setModalState(() {
          error = describeRustApiError(e);
          loadingMoreInvites = false;
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
                                      setModalState(
                                        () => error = describeRustApiError(e),
                                      );
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
                                  await loadAuditPage(setModalState);
                                  inviteEmailController.clear();
                                } catch (e) {
                                  setModalState(
                                    () => error = describeRustApiError(e),
                                  );
                                } finally {
                                  setModalState(() => inviting = false);
                                }
                              },
                        child: Text(inviting ? '生成邀请中…' : '生成邀请链接'),
                      ),
                      if (showWorkspaceOpsStats &&
                          (currentWorkspaceRole == 'owner' ||
                              currentWorkspaceRole == 'admin')) ...<Widget>[
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Text(
                              '内部运维统计',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: loadingWorkspaceStats
                                  ? null
                                  : () => loadWorkspaceStats(setModalState),
                              child: Text(
                                loadingWorkspaceStats ? '读取中…' : '刷新统计',
                              ),
                            ),
                          ],
                        ),
                        if (workspaceStats != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              Chip(
                                label: Text(
                                  '成员 ${workspaceStats!.workspaceMemberCount}',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                label: Text(
                                  '项目 ${workspaceStats!.workspaceProjectCount}',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                label: Text(
                                  '活跃任务 ${workspaceStats!.workspaceActiveJobCount}',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        if (workspaceStatsError != null)
                          SelectableText(
                            workspaceStatsError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                      if (currentWorkspaceRole == 'owner' ||
                          currentWorkspaceRole == 'admin') ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          '平台邀请（服务端）',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('包含已撤销邀请'),
                          value: includeRevokedInvites,
                          onChanged: loading
                              ? null
                              : (v) async {
                                  setModalState(
                                    () => includeRevokedInvites = v,
                                  );
                                  await loadMembers(setModalState);
                                },
                        ),
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
                        if (pendingInvites.isEmpty && !loading)
                          Text(
                            '暂无邀请记录。生成或从服务端加载更多。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
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
                          final chipColor = label == '已过期' || label == '已撤销'
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
                              if (invite.status == 'pending') ...<Widget>[
                                IconButton(
                                  tooltip: '刷新链接（延期并更换 token）',
                                  icon: const Icon(Icons.refresh, size: 18),
                                  onPressed: inviteActionBusyId != null
                                      ? null
                                      : () async {
                                          setModalState(
                                            () =>
                                                inviteActionBusyId = invite.id,
                                          );
                                          try {
                                            final next =
                                                await resendWorkspaceInviteV1(
                                                  token,
                                                  row.workspace.id,
                                                  invite.id,
                                                );
                                            setModalState(() {
                                              final i = pendingInvites
                                                  .indexWhere(
                                                    (e) => e.id == invite.id,
                                                  );
                                              if (i >= 0) {
                                                pendingInvites[i] = next;
                                              }
                                            });
                                            await loadAuditPage(setModalState);
                                          } catch (e) {
                                            setModalState(
                                              () => error =
                                                  describeRustApiError(e),
                                            );
                                          } finally {
                                            setModalState(
                                              () => inviteActionBusyId = null,
                                            );
                                          }
                                        },
                                ),
                                IconButton(
                                  tooltip: '撤销邀请',
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 18,
                                  ),
                                  onPressed: inviteActionBusyId != null
                                      ? null
                                      : () async {
                                          setModalState(
                                            () =>
                                                inviteActionBusyId = invite.id,
                                          );
                                          try {
                                            final next =
                                                await revokeWorkspaceInviteV1(
                                                  token,
                                                  row.workspace.id,
                                                  invite.id,
                                                );
                                            setModalState(() {
                                              if (includeRevokedInvites) {
                                                final i = pendingInvites
                                                    .indexWhere(
                                                      (e) => e.id == invite.id,
                                                    );
                                                if (i >= 0) {
                                                  pendingInvites[i] = next;
                                                }
                                              } else {
                                                pendingInvites.removeWhere(
                                                  (e) => e.id == invite.id,
                                                );
                                              }
                                            });
                                            await loadAuditPage(setModalState);
                                          } catch (e) {
                                            setModalState(
                                              () => error =
                                                  describeRustApiError(e),
                                            );
                                          } finally {
                                            setModalState(
                                              () => inviteActionBusyId = null,
                                            );
                                          }
                                        },
                                ),
                              ],
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
                        if (inviteHasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton(
                              onPressed: loading || loadingMoreInvites
                                  ? null
                                  : () => loadMoreInvites(setModalState),
                              child: Text(
                                loadingMoreInvites ? '加载中…' : '加载更多邀请',
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          '活动记录',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: auditSearchController,
                          decoration: const InputDecoration(
                            labelText:
                                '搜索活动（动作 / actor / target / role / email）',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 6),
                        if (auditRows.isEmpty && !loading)
                          Text(
                            '暂无活动记录。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ...auditRows
                            .where((audit) {
                              final needle = auditSearchController.text
                                  .trim()
                                  .toLowerCase();
                              if (needle.isEmpty) {
                                return true;
                              }
                              final haystack = <String>[
                                audit.action,
                                workspaceAuditActionLabel(audit.action),
                                audit.actorUserId,
                                audit.targetUserId ?? '',
                                '${audit.details['role'] ?? ''}',
                                '${audit.details['email'] ?? ''}',
                                '${audit.details['previous_owner_user_id'] ?? ''}',
                                '${audit.details['new_owner_user_id'] ?? ''}',
                              ].join(' ').toLowerCase();
                              return haystack.contains(needle);
                            })
                            .map((audit) {
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  workspaceAuditActionLabel(audit.action),
                                ),
                                subtitle: SelectableText(
                                  '${audit.createdAt.toLocal().toIso8601String()}\n${buildWorkspaceAuditSummary(audit)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            }),
                        if (auditHasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton(
                              onPressed: loading || loadingMoreAudit
                                  ? null
                                  : () => loadAuditPage(
                                      setModalState,
                                      append: true,
                                    ),
                              child: Text(loadingMoreAudit ? '加载中…' : '加载更多活动'),
                            ),
                          ),
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
                      SelectableText(
                        '当前主 owner: $currentOwnerUserId',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
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
                        ).map((m) {
                          final isPrimaryOwner = m.userId == currentOwnerUserId;
                          final canTransferOwner =
                              currentWorkspaceRole == 'owner' &&
                              row.workspace.workspaceType == 'enterprise' &&
                              !isPrimaryOwner;
                          final canEditRole =
                              m.role == 'member' || m.role == 'admin';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.userId),
                            subtitle: Text(
                              isPrimaryOwner
                                  ? '${m.role} · primary owner'
                                  : m.role,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (canEditRole)
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
                                                () => error =
                                                    describeRustApiError(e),
                                              );
                                            } finally {
                                              setModalState(
                                                () =>
                                                    mutatingMemberUserId = null,
                                              );
                                            }
                                          },
                                  )
                                else
                                  Chip(
                                    label: Text(
                                      isPrimaryOwner ? 'owner' : m.role,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (canTransferOwner)
                                  IconButton(
                                    tooltip: '转让 owner',
                                    onPressed: mutatingMemberUserId != null
                                        ? null
                                        : () async {
                                            final confirmed =
                                                await confirmOwnerTransfer(m);
                                            if (!confirmed) {
                                              return;
                                            }
                                            setModalState(() {
                                              mutatingMemberUserId = m.userId;
                                              error = null;
                                            });
                                            try {
                                              final workspace =
                                                  await transferWorkspaceOwnerV1(
                                                    token,
                                                    row.workspace.id,
                                                    TransferWorkspaceOwnerBody(
                                                      targetUserId: m.userId,
                                                    ),
                                                  );
                                              setModalState(() {
                                                currentOwnerUserId =
                                                    workspace.ownerUserId;
                                                currentWorkspaceRole = 'admin';
                                              });
                                              await loadMembers(setModalState);
                                              await _load();
                                            } catch (e) {
                                              setModalState(
                                                () => error =
                                                    describeRustApiError(e),
                                              );
                                            } finally {
                                              setModalState(
                                                () =>
                                                    mutatingMemberUserId = null,
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.swap_horiz_outlined),
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
                                              () => error =
                                                  describeRustApiError(e),
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
                          );
                        }),
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

  Future<void> _openInvitesDialog(WorkspaceListItem row) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final inviteEmailController = TextEditingController();
    final inviteSearchController = TextEditingController();
    String role = 'member';
    String statusFilter = 'pending';
    final List<WorkspaceInviteResponse> invites = <WorkspaceInviteResponse>[];
    final Set<String> selectedInviteIds = <String>{};
    String? error;
    bool loading = true;
    bool inviting = false;
    String? inviteMgmtBusyId;
    bool includeExpiredInvites = false;
    int pageIndex = 0;
    int pageSize = 10;

    Future<void> loadInvites(StateSetter setModalState) async {
      setModalState(() {
        loading = true;
        error = null;
      });
      try {
        final includeRevoked =
            statusFilter == 'all' || statusFilter == 'revoked';
        final rows = await fetchWorkspaceInvitesAllV1(
          token,
          row.workspace.id,
          status: statusFilter == 'all' ? null : statusFilter,
          pageSize: 120,
          includeRevoked: includeRevoked,
          maxPages: 40,
        );
        setModalState(() {
          invites
            ..clear()
            ..addAll(rows);
          selectedInviteIds.removeWhere(
            (id) => !invites.any((invite) => invite.id == id),
          );
          pageIndex = 0;
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
            if (loading && invites.isEmpty && error == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadInvites(setModalState);
              });
            }
            final filteredInvites = sortWorkspaceInvitesByExpiry(
              filterInvitesByExpiryVisibility(
                filterWorkspaceInvites(invites, inviteSearchController.text),
                includeExpired: includeExpiredInvites,
              ),
            );
            final pageCount = workspaceInvitePageCount(
              filteredInvites,
              pageSize: pageSize,
            );
            final safePageIndex = pageCount == 0
                ? 0
                : pageIndex.clamp(0, pageCount - 1);
            final pagedInvites = paginateWorkspaceInvites(
              filteredInvites,
              pageIndex: safePageIndex,
              pageSize: pageSize,
            );
            return AlertDialog(
              title: Text('邀请管理 · ${row.workspace.name}'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: inviteEmailController,
                        decoration: const InputDecoration(
                          labelText: '邀请邮箱',
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
                        onChanged: inviting
                            ? null
                            : (v) => setModalState(() => role = v ?? 'member'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.tonal(
                            onPressed: inviting
                                ? null
                                : () async {
                                    final email = inviteEmailController.text
                                        .trim();
                                    if (email.isEmpty) {
                                      setModalState(() => error = '请输入邀请邮箱');
                                      return;
                                    }
                                    setModalState(() {
                                      inviting = true;
                                      error = null;
                                    });
                                    try {
                                      await createWorkspaceInviteV1(
                                        token,
                                        row.workspace.id,
                                        CreateWorkspaceInviteBody(
                                          email: email,
                                          role: role,
                                        ),
                                      );
                                      inviteEmailController.clear();
                                      await loadInvites(setModalState);
                                    } catch (e) {
                                      setModalState(() => error = e.toString());
                                    } finally {
                                      setModalState(() => inviting = false);
                                    }
                                  },
                            child: Text(inviting ? '生成中…' : '生成邀请'),
                          ),
                          OutlinedButton(
                            onPressed: loading
                                ? null
                                : () => loadInvites(setModalState),
                            child: const Text('刷新邀请'),
                          ),
                          OutlinedButton(
                            onPressed: selectedInviteIds.isEmpty
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final text = invites
                                        .where(
                                          (invite) => selectedInviteIds
                                              .contains(invite.id),
                                        )
                                        .map(buildInviteCopyText)
                                        .join('\n---\n');
                                    await Clipboard.setData(
                                      ClipboardData(text: text),
                                    );
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '已复制 ${selectedInviteIds.length} 条邀请',
                                        ),
                                      ),
                                    );
                                  },
                            child: const Text('批量复制'),
                          ),
                          TextButton(
                            onPressed: selectedInviteIds.isEmpty
                                ? null
                                : () => setModalState(selectedInviteIds.clear),
                            child: const Text('清空选择'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: statusFilter,
                              decoration: const InputDecoration(
                                labelText: '状态',
                                border: OutlineInputBorder(),
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('pending'),
                                ),
                                DropdownMenuItem(
                                  value: 'accepted',
                                  child: Text('accepted'),
                                ),
                                DropdownMenuItem(
                                  value: 'revoked',
                                  child: Text('revoked'),
                                ),
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('all'),
                                ),
                              ],
                              onChanged: loading
                                  ? null
                                  : (v) async {
                                      setModalState(() {
                                        statusFilter = v ?? 'pending';
                                      });
                                      await loadInvites(setModalState);
                                    },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: pageSize,
                              decoration: const InputDecoration(
                                labelText: '每页条数',
                                border: OutlineInputBorder(),
                              ),
                              items: const <DropdownMenuItem<int>>[
                                DropdownMenuItem(value: 10, child: Text('10')),
                                DropdownMenuItem(value: 20, child: Text('20')),
                                DropdownMenuItem(value: 50, child: Text('50')),
                              ],
                              onChanged: (v) {
                                if (v == null) {
                                  return;
                                }
                                setModalState(() {
                                  pageSize = v;
                                  pageIndex = 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('显示已过期邀请'),
                        value: includeExpiredInvites,
                        onChanged: (v) {
                          setModalState(() {
                            includeExpiredInvites = v;
                            pageIndex = 0;
                          });
                        },
                      ),
                      TextField(
                        controller: inviteSearchController,
                        decoration: const InputDecoration(
                          labelText: '搜索邀请（邮箱 / 角色 / 状态）',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setModalState(() => pageIndex = 0),
                      ),
                      const SizedBox(height: 8),
                      if (loading) const LinearProgressIndicator(),
                      if (!loading && filteredInvites.isEmpty)
                        const Text('当前筛选条件下暂无邀请。'),
                      if (pagedInvites.isNotEmpty) ...<Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              '第 ${pageCount == 0 ? 0 : safePageIndex + 1} / $pageCount 页 · 共 ${filteredInvites.length} 条',
                            ),
                            OutlinedButton(
                              onPressed: safePageIndex <= 0
                                  ? null
                                  : () => setModalState(() => pageIndex -= 1),
                              child: const Text('上一页'),
                            ),
                            OutlinedButton(
                              onPressed: safePageIndex + 1 >= pageCount
                                  ? null
                                  : () => setModalState(() => pageIndex += 1),
                              child: const Text('下一页'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...pagedInvites.map((invite) {
                          final selected = selectedInviteIds.contains(
                            invite.id,
                          );
                          final label = inviteStatusLabel(invite);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              CheckboxListTile(
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: selected,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (checked) {
                                  setModalState(() {
                                    if (checked == true) {
                                      selectedInviteIds.add(invite.id);
                                    } else {
                                      selectedInviteIds.remove(invite.id);
                                    }
                                  });
                                },
                                title: Text('${invite.email} · ${invite.role}'),
                                subtitle: SelectableText(
                                  '$label\n${formatWorkspaceInviteMeta(invite)}\ninvite token: ${invite.token}',
                                ),
                              ),
                              if (invite.status == 'pending')
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 48,
                                    bottom: 8,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    children: <Widget>[
                                      TextButton(
                                        onPressed: inviteMgmtBusyId != null
                                            ? null
                                            : () async {
                                                setModalState(
                                                  () => inviteMgmtBusyId =
                                                      invite.id,
                                                );
                                                try {
                                                  final next =
                                                      await resendWorkspaceInviteV1(
                                                        token,
                                                        row.workspace.id,
                                                        invite.id,
                                                      );
                                                  setModalState(() {
                                                    final i = invites
                                                        .indexWhere(
                                                          (e) =>
                                                              e.id == invite.id,
                                                        );
                                                    if (i >= 0) {
                                                      invites[i] = next;
                                                    }
                                                  });
                                                } catch (e) {
                                                  setModalState(
                                                    () => error = e.toString(),
                                                  );
                                                } finally {
                                                  setModalState(
                                                    () =>
                                                        inviteMgmtBusyId = null,
                                                  );
                                                }
                                              },
                                        child: const Text('重发链接'),
                                      ),
                                      TextButton(
                                        onPressed: inviteMgmtBusyId != null
                                            ? null
                                            : () async {
                                                setModalState(
                                                  () => inviteMgmtBusyId =
                                                      invite.id,
                                                );
                                                try {
                                                  final next =
                                                      await revokeWorkspaceInviteV1(
                                                        token,
                                                        row.workspace.id,
                                                        invite.id,
                                                      );
                                                  setModalState(() {
                                                    final i = invites
                                                        .indexWhere(
                                                          (e) =>
                                                              e.id == invite.id,
                                                        );
                                                    if (i >= 0) {
                                                      invites[i] = next;
                                                    }
                                                  });
                                                } catch (e) {
                                                  setModalState(
                                                    () => error = e.toString(),
                                                  );
                                                } finally {
                                                  setModalState(
                                                    () =>
                                                        inviteMgmtBusyId = null,
                                                  );
                                                }
                                              },
                                        child: const Text('撤销'),
                                      ),
                                    ],
                                  ),
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
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
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
    inviteEmailController.dispose();
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: Text('团队工作区', style: theme.textTheme.titleMedium)),
            const RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: '本机客户端偏好（查看已静默 / 恢复确认）',
            ),
          ],
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
        if (shouldShowInviteTokenHint(
          tokenAutoFilledFromUri: _inviteTokenFromUri,
          tokenText: _acceptInviteTokenController.text,
        )) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            kInviteTokenAutofillHint,
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
        if (items != null &&
            items.isNotEmpty &&
            !hasActiveEnterpriseWorkspace(items)) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  kOnlyPersonalWorkspaceTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  kOnlyPersonalWorkspaceBody,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
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
              final isCurrent = isCurrentWorkspaceRow(
                row,
                widget.currentWorkspaceId,
              );
              return Semantics(
                selected: isCurrent,
                label: buildWorkspaceRowSemanticsLabel(
                  row,
                  isCurrent: isCurrent,
                ),
                child: ListTile(
                  dense: true,
                  selected: isCurrent,
                  selectedTileColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.35),
                  title: Text(w.name),
                  subtitle: Text(
                    '${w.workspaceType} · ${row.role}'
                    '${w.archivedAt != null ? ' · 已归档' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isCurrent)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: const Text('当前'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme.colorScheme.primaryContainer,
                          ),
                        ),
                      if (canManage)
                        Tooltip(
                          message: buildWorkspaceActionTooltip(
                            actionLabel: '管理成员',
                            workspaceName: w.name,
                          ),
                          child: TextButton(
                            onPressed: (_loading || busy)
                                ? null
                                : () => _openMembersDialog(row),
                            child: const Text('成员'),
                          ),
                        ),
                      if (canManage)
                        Tooltip(
                          message: buildWorkspaceActionTooltip(
                            actionLabel: '管理邀请',
                            workspaceName: w.name,
                          ),
                          child: TextButton(
                            onPressed: (_loading || busy)
                                ? null
                                : () => _openInvitesDialog(row),
                            child: const Text('邀请'),
                          ),
                        ),
                      Tooltip(
                        message: buildWorkspaceActionTooltip(
                          actionLabel: '切换到工作区',
                          workspaceName: w.name,
                        ),
                        child: TextButton(
                          onPressed:
                              (_loading || busy || switching || isCurrent)
                              ? null
                              : () => _switchCurrentWorkspace(row),
                          child: switching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('切换到此'),
                        ),
                      ),
                      if (canManage && w.archivedAt == null)
                        Tooltip(
                          message: buildWorkspaceActionTooltip(
                            actionLabel: '归档工作区',
                            workspaceName: w.name,
                          ),
                          child: TextButton(
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
                        ),
                      if (canManage && w.archivedAt != null)
                        Tooltip(
                          message: buildWorkspaceActionTooltip(
                            actionLabel: '恢复工作区',
                            workspaceName: w.name,
                          ),
                          child: TextButton(
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
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
