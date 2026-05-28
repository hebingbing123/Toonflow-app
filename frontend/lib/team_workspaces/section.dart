import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_chip.dart';
import 'package:openflow_app/design_system/components/studio_icon_button.dart';
import 'package:flutter/services.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/studio_code_labels.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'invite_deep_link.dart';
import 'strings.dart';
import 'package:openflow_app/design_system/components/studio_collapsible_filter_panel.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_filter_row.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/components/studio_text_styles.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

// Split into multiple files for maintainability
part 'section_helpers.dart';

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

String formatWorkspaceInviteMeta(
  WorkspaceInviteResponse invite, {
  required AppLocalizations l10n,
}) {
  final expiry = invite.expiresAt.toLocal().toIso8601String();
  final stateText = inviteStatusLabel(invite, l10n: l10n);
  return l10n.teamWorkspaceInviteMetaLine(stateText, expiry);
}

bool isWorkspaceInviteExpired(WorkspaceInviteResponse invite) {
  return invite.expiresAt.isBefore(DateTime.now().toUtc());
}

String inviteStatusLabel(
  WorkspaceInviteResponse invite, {
  required AppLocalizations l10n,
}) {
  if (invite.status == 'revoked') {
    return l10n.teamWorkspaceInviteStatusRevoked;
  }
  if (isWorkspaceInviteExpired(invite)) {
    return l10n.teamWorkspaceInviteStatusExpired;
  }
  if (invite.status == 'pending') {
    return l10n.teamWorkspaceInviteStatusValid;
  }
  if (invite.status == 'accepted') {
    return l10n.teamWorkspaceInviteStatusAccepted;
  }
  return studioUnknownCodeLabel(l10n, invite.status);
}

String buildInviteCopyText(WorkspaceInviteResponse invite) {
  return 'workspace=${invite.workspaceId}\n'
      'email=${invite.email}\n'
      'role=${invite.role}\n'
      'status=${invite.status}\n'
      'expires_at=${invite.expiresAt.toUtc().toIso8601String()}\n'
      'token=${invite.token}';
}

String workspaceAuditActionLabel(
  String action, {
  required AppLocalizations l10n,
}) {
  switch (action) {
    case 'workspace_member_upserted':
      return l10n.teamWorkspaceAuditMemberUpserted;
    case 'workspace_member_role_changed':
      return l10n.teamWorkspaceAuditMemberRoleChanged;
    case 'workspace_member_removed':
      return l10n.teamWorkspaceAuditMemberRemoved;
    case 'workspace_member_left':
      return l10n.teamWorkspaceAuditMemberLeft;
    case 'workspace_owner_transferred':
      return l10n.teamWorkspaceAuditOwnerTransferred;
    case 'workspace_invite_created':
      return l10n.teamWorkspaceAuditInviteCreated;
    case 'workspace_invite_resent':
      return l10n.teamWorkspaceAuditInviteResent;
    case 'workspace_invite_revoked':
      return l10n.teamWorkspaceAuditInviteRevoked;
    case 'workspace_invite_accepted':
      return l10n.teamWorkspaceAuditInviteAccepted;
    default:
      return studioUnknownCodeLabel(l10n, action);
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
    this.debugInitialItems,
    this.onWorkspaceContextChanged,
    this.initialInviteToken,
    this.currentWorkspaceId,
  });

  final String? accessToken;
  final List<WorkspaceListItem>? debugInitialItems;
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
    if (widget.debugInitialItems != null) {
      _items = widget.debugInitialItems;
      return;
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

  Widget _buildStudioHeader(BuildContext context, AppLocalizations l10n) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration:
          studioInsetPanelDecoration(
            context,
            backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: studioShadowColor(context, alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.teamWorkspaceTitle,
                    style: studioPaneTitleStyle(context),
                  ),
                ),
                RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: l10n.taskCenterLocalClientPrefs,
                ),
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
            Text(
              l10n.teamWorkspaceIntro,
              style: studioSectionIntroStyle(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final theme = Theme.of(context);
    if (token == null || token.isEmpty) {
      return Text(
        l10n.teamWorkspaceLoginRequired,
        style: theme.textTheme.bodyMedium,
      );
    }

    final items = _items;

    return Padding(
      padding: const EdgeInsets.only(top: StudioSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boundedHeight = constraints.maxHeight.isFinite;
          return CustomScrollView(
            shrinkWrap: !boundedHeight,
            physics: boundedHeight
                ? null
                : const NeverScrollableScrollPhysics(),
            slivers: <Widget>[
          SliverToBoxAdapter(child: _buildStudioHeader(context, l10n)),
          const SliverToBoxAdapter(
            child: SizedBox(height: StudioLayoutSpacing.stackMedium),
          ),
          SliverToBoxAdapter(
            child: StudioCollapsibleFilterPanel(
              collapsible: true,
              title: l10n.teamWorkspaceCreateAction,
              child: StudioFilterRow(
                wideLayout: StudioFilterWideLayout.toolbarRow,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.teamWorkspaceEnterpriseNameLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  FilledButton(
                    style: studioFormPrimaryButtonStyle(context),
                    onPressed: _creating ? null : _create,
                    child: Text(
                      _creating
                          ? l10n.teamWorkspaceCreating
                          : l10n.teamWorkspaceCreateAction,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (shouldShowInviteTokenHint(
            tokenAutoFilledFromUri: _inviteTokenFromUri,
            tokenText: _acceptInviteTokenController.text,
          ))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: StudioSpacing.xs),
                child: Text(
                  inviteTokenAutofillHint(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: StudioSpacing.sm)),
          SliverToBoxAdapter(
            child: StudioCollapsibleFilterPanel(
              collapsible: true,
              title: l10n.teamWorkspaceAcceptInviteAction,
              subtitle: _acceptInviteTokenController.text.trim().isNotEmpty
                  ? l10n.teamWorkspaceInviteTokenInputLabel
                  : null,
              child: StudioFilterRow(
                wideLayout: StudioFilterWideLayout.toolbarRow,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _acceptInviteTokenController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.teamWorkspaceInviteTokenInputLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    style: studioFormTonalButtonStyle(context),
                    onPressed: _acceptingInvite ? null : _acceptInvite,
                    child: Text(
                      _acceptingInvite
                          ? l10n.teamWorkspaceJoining
                          : l10n.teamWorkspaceAcceptInviteAction,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: StudioSpacing.sm)),
          SliverToBoxAdapter(
            child: StudioSwitchListRow(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.teamWorkspaceShowArchivedToggle),
              value: _includeArchived,
              onChanged: _loading
                  ? null
                  : (bool v) {
                      setState(() => _includeArchived = v);
                      _load();
                    },
            ),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: _loading
                    ? l10n.teamWorkspaceLoading
                    : l10n.teamWorkspaceRefreshList,
                child: TextButton.icon(
                style: studioFormTextButtonIconStyle(context),
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _loading
                      ? l10n.teamWorkspaceLoading
                      : l10n.teamWorkspaceRefreshList,
                ),
              ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: StudioSpacing.xs)),
          if (_loading && items == null)
            const SliverToBoxAdapter(
              child: StudioListSkeleton(
                itemCount: 6,
                scrollable: false,
                padding: EdgeInsets.symmetric(
                  horizontal: StudioSpacing.sm,
                  vertical: StudioSpacing.xs,
                ),
              ),
            )
          else if (items == null && !_loading)
            SliverToBoxAdapter(
              child: StudioEmptyState.loadFailed(
                context,
                error: _error,
                title: l10n.teamWorkspaceNoListDataHint,
                onRetry: _load,
              ),
            )
          else if (items != null && items.isEmpty)
            SliverToBoxAdapter(
              child: StudioEmptyState.emptyData(
                title: l10n.teamWorkspaceNoWorkspacesHint,
                icon: Icons.groups_outlined,
                actionLabel: l10n.teamWorkspaceRefreshList,
                onAction: _load,
              ),
            )
          else ...<Widget>[
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                  child: StudioApiErrorCallout(error: _error!, onRetry: _load),
                ),
              ),
            if (items != null &&
                items.isNotEmpty &&
                !hasActiveEnterpriseWorkspace(items))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        StudioSpacing.radiusDense,
                      ),
                      border: Border.all(
                        color: studioPanelBorderColor(context),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          onlyPersonalWorkspaceTitle(l10n),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: StudioSpacing.xs),
                        Text(
                          onlyPersonalWorkspaceBody(l10n),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final row = items![index];
                final tokens = StudioTokens.of(context);
                final w = row.workspace;
                final busy = _patchingWorkspaceId == w.id;
                final switching = _switchingWorkspaceId == w.id;
                final canManage = _canArchiveOrRestore(row);
                final isCurrent = isCurrentWorkspaceRow(
                  row,
                  widget.currentWorkspaceId,
                );

                final tile = studioStaggeredItem(
                  index,
                  entranceKey: items.length,
                  child: StudioListRow(
                    dense: true,
                    selected: isCurrent,
                    selectedTileColor: tokens.primarySoft.withValues(
                      alpha: 0.35,
                    ),
                    onTap: (_loading || busy || switching || isCurrent)
                        ? null
                        : () => _switchCurrentWorkspace(row),
                    trailingContextMenuItems: <StudioContextMenuItem>[
                      if (!isCurrent)
                        StudioContextMenuItem(
                          label: l10n.teamWorkspaceSwitchHereAction,
                          icon: Icons.swap_horiz,
                          enabled: !_loading && !busy && !switching,
                          onSelected: () => _switchCurrentWorkspace(row),
                        ),
                      if (canManage)
                        StudioContextMenuItem(
                          label: l10n.teamWorkspaceMembersShortAction,
                          icon: Icons.group_outlined,
                          enabled: !_loading && !busy,
                          onSelected: () => _openMembersDialog(row),
                        ),
                      if (canManage)
                        StudioContextMenuItem(
                          label: l10n.teamWorkspaceInvitesShortAction,
                          icon: Icons.mail_outline,
                          enabled: !_loading && !busy,
                          onSelected: () => _openInvitesDialog(row),
                        ),
                      if (canManage && w.archivedAt == null)
                        StudioContextMenuItem(
                          label: l10n.teamWorkspaceArchiveAction,
                          icon: Icons.archive_outlined,
                          enabled: !_loading && !busy,
                          onSelected: () => _confirmArchive(row),
                        ),
                      if (canManage && w.archivedAt != null)
                        StudioContextMenuItem(
                          label: l10n.teamWorkspaceRestoreAction,
                          icon: Icons.unarchive_outlined,
                          enabled: !_loading && !busy,
                          onSelected: () => _setArchive(row, false),
                        ),
                    ],
                    title: Text(
                      w.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${w.workspaceType} · ${row.role}'
                      '${w.archivedAt != null ? ' · ${l10n.teamWorkspaceArchivedBadge}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: StudioSpacing.xs,
                            ),
                            child: StudioChip(
                              label: Text(l10n.teamWorkspaceCurrentBadge),
                              backgroundColor: tokens.primarySoft,
                            ),
                          ),
                        if (canManage)
                          Tooltip(
                            message: buildWorkspaceActionTooltip(
                              l10n: l10n,
                              actionLabel:
                                  l10n.teamWorkspaceManageMembersAction,
                              workspaceName: w.name,
                            ),
                            child: TextButton(
                              onPressed: (_loading || busy)
                                  ? null
                                  : () => _openMembersDialog(row),
                              child: Text(l10n.teamWorkspaceMembersShortAction),
                            ),
                          ),
                        if (canManage)
                          Tooltip(
                            message: buildWorkspaceActionTooltip(
                              l10n: l10n,
                              actionLabel:
                                  l10n.teamWorkspaceManageInvitesAction,
                              workspaceName: w.name,
                            ),
                            child: TextButton(
                              onPressed: (_loading || busy)
                                  ? null
                                  : () => _openInvitesDialog(row),
                              child: Text(l10n.teamWorkspaceInvitesShortAction),
                            ),
                          ),
                        Tooltip(
                          message: buildWorkspaceActionTooltip(
                            l10n: l10n,
                            actionLabel: l10n.teamWorkspaceSwitchActionLabel,
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
                                : Text(l10n.teamWorkspaceSwitchHereAction),
                          ),
                        ),
                        if (canManage && w.archivedAt == null)
                          Tooltip(
                            message: buildWorkspaceActionTooltip(
                              l10n: l10n,
                              actionLabel: l10n.teamWorkspaceArchiveActionLabel,
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
                                  : Text(l10n.teamWorkspaceArchiveAction),
                            ),
                          ),
                        if (canManage && w.archivedAt != null)
                          Tooltip(
                            message: buildWorkspaceActionTooltip(
                              l10n: l10n,
                              actionLabel: l10n.teamWorkspaceRestoreActionLabel,
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
                                  : Text(l10n.teamWorkspaceRestoreAction),
                            ),
                          ),
                      ],
                    ),
                  ),
                );

                if (index == 0) {
                  return tile;
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[const Divider(height: 1), tile],
                );
              }, childCount: items?.length ?? 0),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: StudioSpacing.md)),
            ],
          );
        },
      ),
    );
  }
}
