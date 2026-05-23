// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unqualified_reference_to_static_member_of_extended_type

part of 'section.dart';

/// Helper methods for TeamWorkspacesSection
extension _TeamWorkspacesSectionHelpers on _TeamWorkspacesSectionState {
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
      final l10n = resolveAppLocalizationsForErrors(context);
      showRustApiSnackBarIfRustThenDescribeUserVisible(
        e,
        l10n: l10n,
        onMessage: (message) {
          setState(() {
            _error = message;
            _loading = false;
          });
        },
      );
    }
  }

  Future<void> _create() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.teamWorkspaceEnterEnterpriseName)),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.teamWorkspaceCreated)));
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.teamWorkspaceCreateFailed(describeUserVisibleApiErrorResolved(context, e)),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _acceptInvite() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final inviteToken = _acceptInviteTokenController.text.trim();
    if (inviteToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.teamWorkspaceEnterInviteToken)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.teamWorkspaceInviteAcceptedAndJoined)),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.teamWorkspaceAcceptInviteFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
    String roleOptionLabel(String value) {
      return switch (value) {
        'member' => l10n.teamWorkspaceRoleOptionMember,
        'admin' => l10n.teamWorkspaceRoleOptionAdmin,
        'owner' => l10n.teamWorkspaceRoleOptionOwner,
        _ => value,
      };
    }

    final showWorkspaceOpsStats = kInternalOpsToken.trim().isNotEmpty;
    WorkspaceStatsResponse? workspaceStats;
    String? workspaceStatsError;
    bool loadingWorkspaceStats = false;

    Future<bool> confirmOwnerTransfer(WorkspaceMemberResponse member) async {
      return await showStudioDialog<bool>(
            context: context,
            builder: (context) {
              return StudioAlertDialog(
                title: Text(l10n.teamWorkspaceTransferOwnerTitle),
                content: SelectableText(
                  l10n.teamWorkspaceTransferOwnerBody(
                    row.workspace.name,
                    currentOwnerUserId,
                    member.userId,
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.helpHubDialogClose),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.teamWorkspaceConfirmTransferOwner),
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
          error = describeUserVisibleApiErrorResolved(context, e);
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
          workspaceStatsError = describeUserVisibleApiErrorResolved(context, e);
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
          error = describeUserVisibleApiErrorResolved(context, e);
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
          error = describeUserVisibleApiErrorResolved(context, e);
          loadingMoreInvites = false;
        });
      }
    }

    if (!mounted) {
      return;
    }
    await showStudioDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading && members.isEmpty && error == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadMembers(setModalState);
              });
            }
            return StudioAlertDialog(
              title: Text(
                l10n.teamWorkspaceMembersDialogTitle(row.workspace.name),
              ),
              content: SizedBox(
                width: studioConstrainedDialogWidth(context, maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: userIdController,
                        decoration: InputDecoration(
                          labelText: l10n.teamWorkspaceUserUuidLabel,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StudioDropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: InputDecoration(
                          labelText: l10n.teamWorkspaceRoleLabel,
                          border: OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'member',
                            child: Text(roleOptionLabel('member')),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text(roleOptionLabel('admin')),
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
                                      setModalState(
                                        () => error =
                                            l10n.teamWorkspaceEnterUserUuid,
                                      );
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
                                        () => error = describeUserVisibleApiErrorResolved(context, e),
                                      );
                                    } finally {
                                      setModalState(() => adding = false);
                                    }
                                  },
                            child: Text(
                              adding
                                  ? l10n.teamWorkspaceAddingMember
                                  : l10n.teamWorkspaceAddMemberAction,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: loading
                                ? null
                                : () => loadMembers(setModalState),
                            child: Text(l10n.teamWorkspaceRefreshAction),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: inviteEmailController,
                        decoration: InputDecoration(
                          labelText: l10n.teamWorkspaceInviteEmailLabel,
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
                                  setModalState(
                                    () => error =
                                        l10n.teamWorkspaceEnterInviteEmail,
                                  );
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
                                    () => error = describeUserVisibleApiErrorResolved(context, e),
                                  );
                                } finally {
                                  setModalState(() => inviting = false);
                                }
                              },
                        child: Text(
                          inviting
                              ? l10n.teamWorkspaceGeneratingInvite
                              : l10n.teamWorkspaceGenerateInviteLinkAction,
                        ),
                      ),
                      if (showWorkspaceOpsStats &&
                          (currentWorkspaceRole == 'owner' ||
                              currentWorkspaceRole == 'admin')) ...<Widget>[
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Text(
                              l10n.teamWorkspaceOpsStatsTitle,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: loadingWorkspaceStats
                                  ? null
                                  : () => loadWorkspaceStats(setModalState),
                              child: Text(
                                loadingWorkspaceStats
                                    ? l10n.teamWorkspaceReading
                                    : l10n.teamWorkspaceRefreshStats,
                              ),
                            ),
                          ],
                        ),
                        if (workspaceStats != null)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              StudioChip(
                                label: Text(
                                  l10n.teamWorkspaceStatsMembers(
                                    workspaceStats!.workspaceMemberCount,
                                  ),
                                ),
                              ),
                              StudioChip(
                                label: Text(
                                  l10n.teamWorkspaceStatsProjects(
                                    workspaceStats!.workspaceProjectCount,
                                  ),
                                ),
                              ),
                              StudioChip(
                                label: Text(
                                  l10n.teamWorkspaceStatsActiveJobs(
                                    workspaceStats!.workspaceActiveJobCount,
                                  ),
                                ),
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
                          l10n.teamWorkspacePlatformInvitesTitle,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(l10n.teamWorkspaceIncludeRevokedInvites),
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
                          title: Text(l10n.teamWorkspaceShowExpiredInvites),
                          value: includeExpiredInvites,
                          onChanged: (v) =>
                              setModalState(() => includeExpiredInvites = v),
                        ),
                        TextField(
                          controller: inviteSearchController,
                          decoration: InputDecoration(
                            labelText: l10n.teamWorkspaceSearchInvitesHint,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: StudioLayoutSpacing.titleTight),
                        if (pendingInvites.isEmpty && !loading)
                          StudioEmptyState.emptyData(
                            title: l10n.teamWorkspaceNoInviteRecords,
                            icon: Icons.mail_outline,
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
                          final label = inviteStatusLabel(invite, l10n: l10n);
                          final chipColor =
                              invite.status == 'revoked' ||
                                  isWorkspaceInviteExpired(invite)
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
                                        StudioChip(
                                          label: Text(label),
                                          backgroundColor: chipColor,
                                        ),
                                      ],
                                    ),
                                    SelectableText(
                                      '${formatWorkspaceInviteMeta(invite, l10n: l10n)}\n${l10n.teamWorkspaceInviteTokenLine(invite.token)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (invite.status == 'pending') ...<Widget>[
                                IconButton(
                                  tooltip: l10n
                                      .teamWorkspaceRefreshInviteLinkTooltip,
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
                                                  describeUserVisibleApiErrorResolved(context, e),
                                            );
                                          } finally {
                                            setModalState(
                                              () => inviteActionBusyId = null,
                                            );
                                          }
                                        },
                                ),
                                IconButton(
                                  tooltip:
                                      l10n.teamWorkspaceRevokeInviteTooltip,
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
                                                  describeUserVisibleApiErrorResolved(context, e),
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
                                tooltip:
                                    l10n.teamWorkspaceCopyInviteInfoTooltip,
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
                                      content: Text(
                                        l10n.teamWorkspaceCopiedInvite(
                                          invite.email,
                                        ),
                                      ),
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
                                loadingMoreInvites
                                    ? l10n.teamWorkspaceLoading
                                    : l10n.teamWorkspaceLoadMoreInvites,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.teamWorkspaceActivityRecordsTitle,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: auditSearchController,
                          decoration: InputDecoration(
                            labelText: l10n.teamWorkspaceSearchActivityHint,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 8),
                        if (auditRows.isEmpty && !loading)
                          StudioEmptyState.emptyData(
                            title: l10n.teamWorkspaceNoActivityRecords,
                            icon: Icons.history_outlined,
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
                                workspaceAuditActionLabel(
                                  audit.action,
                                  l10n: l10n,
                                ),
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
                                  workspaceAuditActionLabel(
                                    audit.action,
                                    l10n: l10n,
                                  ),
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
                              child: Text(
                                loadingMoreAudit
                                    ? l10n.teamWorkspaceLoading
                                    : l10n.teamWorkspaceLoadMoreActivity,
                              ),
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
                      const SizedBox(height: 16),
                      SelectableText(
                        l10n.teamWorkspaceCurrentOwnerLine(currentOwnerUserId),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: memberSearchController,
                        decoration: InputDecoration(
                          labelText: l10n.teamWorkspaceSearchMembersHint,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 8),
                      if (members.isEmpty && !loading)
                        StudioEmptyState.emptyData(
                          title: l10n.teamWorkspaceNoMembers,
                          icon: Icons.group_outlined,
                        ),
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
                                  ? l10n.teamWorkspaceMemberPrimaryOwnerLine(
                                      roleOptionLabel(m.role),
                                    )
                                  : roleOptionLabel(m.role),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (canEditRole)
                                  StudioDropdownButton<String>(
                                    value: m.role,
                                    items: <DropdownMenuItem<String>>[
                                      DropdownMenuItem(
                                        value: 'member',
                                        child: Text(roleOptionLabel('member')),
                                      ),
                                      DropdownMenuItem(
                                        value: 'admin',
                                        child: Text(roleOptionLabel('admin')),
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
                                                    describeUserVisibleApiErrorResolved(context, e),
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
                                  StudioChip(
                                    label: Text(
                                      roleOptionLabel(
                                        isPrimaryOwner ? 'owner' : m.role,
                                      ),
                                    ),
                                  ),
                                if (canTransferOwner)
                                  IconButton(
                                    tooltip:
                                        l10n.teamWorkspaceTransferOwnerTooltip,
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
                                                    describeUserVisibleApiErrorResolved(context, e),
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
                                  tooltip:
                                      l10n.teamWorkspaceRemoveMemberTooltip,
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
                                                  describeUserVisibleApiErrorResolved(context, e),
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
                              SnackBar(
                                content: Text(l10n.teamWorkspaceLeftWorkspace),
                              ),
                            );
                            if (widget.onWorkspaceContextChanged != null) {
                              await widget.onWorkspaceContextChanged!();
                            }
                            await _load();
                          } catch (e) {
                            setModalState(() {
                              error = describeUserVisibleApiErrorResolved(context, e);
                              leaving = false;
                            });
                          }
                        },
                  child: Text(
                    leaving
                        ? l10n.teamWorkspaceLeaving
                        : l10n.teamWorkspaceLeaveWorkspaceAction,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.helpHubDialogClose),
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
    String roleOptionLabel(String value) {
      return switch (value) {
        'member' => l10n.teamWorkspaceRoleOptionMember,
        'admin' => l10n.teamWorkspaceRoleOptionAdmin,
        _ => value,
      };
    }

    String statusOptionLabel(String value) {
      return switch (value) {
        'pending' => l10n.teamWorkspaceStatusOptionPending,
        'accepted' => l10n.teamWorkspaceStatusOptionAccepted,
        'revoked' => l10n.teamWorkspaceStatusOptionRevoked,
        'all' => l10n.teamWorkspaceStatusOptionAll,
        _ => value,
      };
    }

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
          error = describeUserVisibleApiErrorResolved(context, e);
          loading = false;
        });
      }
    }

    if (!mounted) {
      return;
    }
    await showStudioDialog<void>(
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
            return StudioAlertDialog(
              title: Text(
                l10n.teamWorkspaceInvitesDialogTitle(row.workspace.name),
              ),
              content: SizedBox(
                width: studioConstrainedDialogWidth(context, maxWidth: 560),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: inviteEmailController,
                        decoration: InputDecoration(
                          labelText: l10n.teamWorkspaceInviteEmailLabel,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      StudioDropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: InputDecoration(
                          labelText: l10n.teamWorkspaceRoleLabel,
                          border: OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'member',
                            child: Text(roleOptionLabel('member')),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text(roleOptionLabel('admin')),
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
                                      setModalState(
                                        () => error =
                                            l10n.teamWorkspaceEnterInviteEmail,
                                      );
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
                                      setModalState(
                                        () => error =
                                            describeUserVisibleApiErrorResolved(
                                              context,
                                              e,
                                            ),
                                      );
                                    } finally {
                                      setModalState(() => inviting = false);
                                    }
                                  },
                            child: Text(
                              inviting
                                  ? l10n.teamWorkspaceGenerating
                                  : l10n.teamWorkspaceGenerateInviteAction,
                            ),
                          ),
                          OutlinedButton(
                            onPressed: loading
                                ? null
                                : () => loadInvites(setModalState),
                            child: Text(l10n.teamWorkspaceRefreshInvitesAction),
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
                                          l10n.teamWorkspaceCopiedInviteCount(
                                            selectedInviteIds.length,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            child: Text(l10n.teamWorkspaceBulkCopyAction),
                          ),
                          TextButton(
                            onPressed: selectedInviteIds.isEmpty
                                ? null
                                : () => setModalState(selectedInviteIds.clear),
                            child: Text(l10n.teamWorkspaceClearSelectionAction),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: StudioDropdownButtonFormField<String>(
                              initialValue: statusFilter,
                              decoration: InputDecoration(
                                labelText: l10n.teamWorkspaceStatusLabel,
                                border: OutlineInputBorder(),
                              ),
                              items: <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text(statusOptionLabel('pending')),
                                ),
                                DropdownMenuItem(
                                  value: 'accepted',
                                  child: Text(statusOptionLabel('accepted')),
                                ),
                                DropdownMenuItem(
                                  value: 'revoked',
                                  child: Text(statusOptionLabel('revoked')),
                                ),
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text(statusOptionLabel('all')),
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
                            child: StudioDropdownButtonFormField<int>(
                              initialValue: pageSize,
                              decoration: InputDecoration(
                                labelText: l10n.teamWorkspacePageSizeLabel,
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
                        title: Text(l10n.teamWorkspaceShowExpiredInvites),
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
                        decoration: InputDecoration(
                          labelText: l10n.teamWorkspaceSearchInvitesHint,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setModalState(() => pageIndex = 0),
                      ),
                      const SizedBox(height: 8),
                      if (loading) const LinearProgressIndicator(),
                      if (!loading && filteredInvites.isEmpty)
                        StudioEmptyState.noResults(
                          title: l10n.teamWorkspaceNoInvitesForCurrentFilters,
                        ),
                      if (pagedInvites.isNotEmpty) ...<Widget>[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              l10n.teamWorkspacePagingLine(
                                pageCount == 0 ? 0 : safePageIndex + 1,
                                pageCount,
                                filteredInvites.length,
                              ),
                            ),
                            OutlinedButton(
                              onPressed: safePageIndex <= 0
                                  ? null
                                  : () => setModalState(() => pageIndex -= 1),
                              child: Text(l10n.teamWorkspacePrevPageAction),
                            ),
                            OutlinedButton(
                              onPressed: safePageIndex + 1 >= pageCount
                                  ? null
                                  : () => setModalState(() => pageIndex += 1),
                              child: Text(l10n.teamWorkspaceNextPageAction),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...pagedInvites.map((invite) {
                          final selected = selectedInviteIds.contains(
                            invite.id,
                          );
                          final label = inviteStatusLabel(invite, l10n: l10n);
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
                                title: Text(
                                  '${invite.email} · ${roleOptionLabel(invite.role)}',
                                ),
                                subtitle: SelectableText(
                                  '$label\n${formatWorkspaceInviteMeta(invite, l10n: l10n)}\n${l10n.teamWorkspaceInviteTokenLine(invite.token)}',
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
                                                    () => error =
                                                        describeUserVisibleApiErrorResolved(
                                                      context,
                                                      e,
                                                    ),
                                                  );
                                                } finally {
                                                  setModalState(
                                                    () =>
                                                        inviteMgmtBusyId = null,
                                                  );
                                                }
                                              },
                                        child: Text(
                                          l10n.teamWorkspaceResendInviteLinkAction,
                                        ),
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
                                                    () => error =
                                                        describeUserVisibleApiErrorResolved(
                                                      context,
                                                      e,
                                                    ),
                                                  );
                                                } finally {
                                                  setModalState(
                                                    () =>
                                                        inviteMgmtBusyId = null,
                                                  );
                                                }
                                              },
                                        child: Text(
                                          l10n.teamWorkspaceRevokeAction,
                                        ),
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
                  child: Text(l10n.helpHubDialogClose),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final ok = await showStudioDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StudioAlertDialog(
        title: Text(l10n.teamWorkspaceArchiveDialogTitle),
        content: Text(l10n.teamWorkspaceArchiveDialogBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.helpHubDialogClose),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.teamWorkspaceArchiveAction),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _setArchive(row, true);
    }
  }

  Future<void> _setArchive(WorkspaceListItem row, bool archive) async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            archive ? l10n.teamWorkspaceArchived : l10n.teamWorkspaceRestored,
          ),
        ),
      );
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
      ).showSnackBar(
        SnackBar(
          content: Text(
            l10n.teamWorkspaceOpFailed(describeUserVisibleApiErrorResolved(context, e)),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _patchingWorkspaceId = null);
      }
    }
  }

  Future<void> _switchCurrentWorkspace(WorkspaceListItem row) async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        SnackBar(
          content: Text(l10n.teamWorkspaceSwitchedTo(row.workspace.name)),
        ),
      );
      if (widget.onWorkspaceContextChanged != null) {
        await widget.onWorkspaceContextChanged!();
      }
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.teamWorkspaceSwitchFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _switchingWorkspaceId = null);
      }
    }
  }

}
