import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_icon_button.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/components/studio_skeleton.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../l10n/app_localizations.dart';
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectRows = const <ProjectMemberResponse>[];
        _pendingRole.clear();
        _loading = false;
        if (e is RustApiException && e.statusCode == 403) {
          _projectMembersForbidden = true;
        } else {
          _error = describeUserVisibleApiErrorResolved(context, e);
        }
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _workspaceRows = const <WorkspaceMemberResponse>[];
        _loadingWorkspaceMembers = false;
        _selectedWorkspaceCandidateUserId = null;
        if (e is RustApiException && e.statusCode == 403) {
          _workspaceMembersForbidden = true;
        } else {
          _workspaceMembersError = describeUserVisibleApiErrorResolved(context, e);
        }
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
      final l10n = resolveAppLocalizationsForErrors(context);
      _showSnack(l10n.projectMembersSnackInvalidUuid);
      return;
    }
    await _createMember(raw, role: _newRole);
  }

  Future<void> _addWorkspaceCandidate() async {
    final userId = _selectedWorkspaceCandidateUserId;
    if (userId == null || userId.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      _showSnack(l10n.projectMembersSnackNoCandidates);
      return;
    }
    await _createMember(userId, role: _newRole);
  }

  Future<void> _createMember(String userId, {required String role}) async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
      _showSnack(l10n.projectMembersSnackMemberAdded);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      _showSnack(describeUserVisibleApiErrorResolved(context, e));
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
      _showSnack(l10n.projectMembersSnackRoleUpdated);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      _showSnack(describeUserVisibleApiErrorResolved(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _savingUsers.remove(userId);
        });
      }
    }
  }

  Future<void> _remove(String userId) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final confirmed = await showStudioConfirmDialog(
      context: context,
      title: l10n.projectMembersTooltipRemoveAcl,
      message:
          'This will remove the explicit ACL for this member from the project.',
      confirmLabel: l10n.projectMembersTooltipRemoveAcl,
      cancelLabel: l10n.globalSearchCancel,
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _removingUsers.add(userId);
    });
    try {
      await deleteProjectMemberV1(widget.accessToken, widget.projectId, userId);
      if (!mounted) return;
      _showSnack(l10n.projectMembersSnackAclRemoved);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      _showSnack(describeUserVisibleApiErrorResolved(context, e));
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
    final l10n = resolveAppLocalizationsForErrors(context);
    _showSnack(l10n.projectMembersSnackUserIdCopied);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
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
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: BoxDecoration(
        border: Border.all(color: studioPanelBorderColor(context)),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
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
                    Text(l10n.projectMembersTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      _aclEnabled
                          ? l10n.projectMembersAclEnabledIntro
                          : l10n.projectMembersAclInheritedIntro,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: StudioTokens.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: StudioSpacing.sm),
              Wrap(
                spacing: StudioSpacing.xs,
                runSpacing: StudioSpacing.xs,
                alignment: WrapAlignment.end,
                children: [
                  _buildSummaryChip(
                    theme,
                    label: l10n.projectMembersChipMode,
                    value: _aclEnabled ? 'restricted' : 'inherited',
                  ),
                  _buildSummaryChip(
                    theme,
                    label: l10n.projectMembersChipExplicitMembers,
                    value: '${_projectRows.length}',
                  ),
                  if (widget.workspaceId != null)
                    _buildSummaryChip(
                      theme,
                      label: l10n.projectMembersChipCandidates,
                      value: _workspaceRows.isEmpty
                          ? (_loadingWorkspaceMembers ? '...' : '${assignableCandidates.length}')
                          : '${assignableCandidates.length}',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          StudioAsyncDataView(
            loading: _loading,
            error: _error,
            onRetry: _reload,
            loadingPlaceholder: StudioLoadingPlaceholder.list,
            loadingItemCount: 2,
            scrollableLoading: false,
            child: _projectMembersForbidden
                ? _buildForbiddenNotice(theme, l10n)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildAddSection(theme, l10n, assignableCandidates),
                      const SizedBox(height: StudioSpacing.sm),
                      _buildExplicitMembersSection(theme, l10n),
                    ],
                  ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: studioFormTextButtonIconStyle(context),
              onPressed: _loading || _loadingWorkspaceMembers ? null : _reload,
              icon: const Icon(Icons.refresh, size: StudioIconSize.sm),
              label: Text(l10n.projectMembersButtonRefresh),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForbiddenNotice(ThemeData theme, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        color: theme.colorScheme.surface,
        border: Border.all(color: studioPanelBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.projectMembersForbiddenTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.projectMembersForbiddenBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddSection(
    ThemeData theme,
    AppLocalizations l10n,
    List<WorkspaceMemberResponse> assignableCandidates,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        color: theme.colorScheme.surface,
        border: Border.all(color: studioPanelBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.projectMembersAddSectionTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.projectMembersAddSectionIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          Row(
            children: [
              Expanded(
                child: StudioDropdownButtonFormField<String>(
                  key: ValueKey<String>('newRole-$_newRole'),
                  initialValue: _newRole,
                  decoration: InputDecoration(
                    labelText: l10n.projectMembersFieldGrantRole,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: 'viewer', child: Text(l10n.projectMembersRoleViewer)),
                    DropdownMenuItem(value: 'editor', child: Text(l10n.projectMembersRoleEditor)),
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
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          if (_loadingWorkspaceMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: StudioSpacing.xs),
              child: StudioSkeleton(height: StudioLayoutSize.skeletonAvatar),
            )
          else if (_workspaceMembersError != null)
            StudioApiErrorCallout(
              error: _workspaceMembersError!,
              onRetry: _loadWorkspaceMembers,
              emphasis: StudioApiErrorCalloutEmphasis.subtle,
            )
          else if (_workspaceMembersForbidden)
            Text(
              l10n.projectMembersForbiddenWorkspaceMembers,
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
              ),
            )
          else if (widget.workspaceId == null || widget.workspaceId!.trim().isEmpty)
            StudioEmptyState.emptyData(
              title: l10n.projectMembersNoWorkspaceContext,
              icon: Icons.workspaces_outlined,
            )
          else ...[
            if (assignableCandidates.isEmpty)
              StudioEmptyState.emptyData(
                title: l10n.projectMembersNoCandidates,
                icon: Icons.person_search_outlined,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: StudioDropdownButtonFormField<String>(
                      key: ValueKey<String>(
                        'ws-${_selectedWorkspaceCandidateUserId ?? ''}',
                      ),
                      initialValue: _selectedWorkspaceCandidateUserId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.projectMembersFieldSelectFromWorkspace,
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
                  const SizedBox(width: StudioSpacing.xs),
                  FilledButton.tonalIcon(
                    style: studioFormIconLabeledButtonStyle(context),
                    onPressed: _adding ? null : _addWorkspaceCandidate,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(l10n.projectMembersButtonAdd),
                  ),
                ],
              ),
          ],
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualUserIdCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_adding) {
                      unawaited(_addManual());
                    }
                  },
                  decoration: InputDecoration(
                    labelText: l10n.projectMembersFieldManualUserId,
                    hintText: l10n.projectMembersFieldManualUserIdHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: StudioSpacing.xs),
              FilledButton(
                style: studioFormPrimaryButtonStyle(context),
                onPressed: _adding ? null : _addManual,
                child: Text(l10n.projectMembersButtonAddByUuid),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExplicitMembersSection(ThemeData theme, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        color: theme.colorScheme.surface,
        border: Border.all(color: studioPanelBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.projectMembersExplicitSectionTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            _projectRows.isEmpty
                ? l10n.projectMembersExplicitEmptyIntro
                : l10n.projectMembersExplicitNonEmptyIntro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          if (_projectRows.isEmpty)
            StudioEmptyState.emptyData(
              title: l10n.projectMembersExplicitEmptyState,
              icon: Icons.group_outlined,
            )
          else
            ..._projectRows.toList().asMap().entries.map(
              (entry) => studioStaggeredItem(
                entry.key,
                entranceKey: _projectRows.length,
                child: _buildExplicitMemberRow(theme, l10n, entry.value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExplicitMemberRow(ThemeData theme, AppLocalizations l10n, ProjectMemberResponse row) {
    final pendingRole = _pendingRole[row.userId] ?? row.role;
    final workspaceRole = _workspaceRows
        .where((candidate) => candidate.userId == row.userId)
        .map((candidate) => candidate.role)
        .cast<String?>()
        .firstOrNull;
    final saving = _savingUsers.contains(row.userId);
    final removing = _removingUsers.contains(row.userId);

    return StudioContextMenu(
      items: studioBuildListRowContextMenu(
        context: context,
        onCopy: () => _copyUserId(row.userId),
        onDelete: saving || removing ? null : () => _remove(row.userId),
      ),
      child: Padding(
      padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
          border: Border.all(color: studioPanelBorderColor(context)),
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
                StudioIconButton(
                  icon: Icons.copy_all_outlined,
                  label: l10n.projectMembersTooltipCopyUserId,
                  size: StudioIconSize.sm,
                  onPressed: () => _copyUserId(row.userId),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.xs),
            Wrap(
              spacing: StudioSpacing.xs,
              runSpacing: StudioSpacing.xs,
              children: [
                _buildTag(theme, l10n.projectMembersTagExplicitRole, row.role),
                if (workspaceRole != null)
                  _buildTag(theme, l10n.projectMembersTagWorkspaceRole, workspaceRole),
                _buildTag(
                  theme,
                  l10n.projectMembersTagUpdatedAt,
                  _formatShortDateTime(row.updatedAt),
                ),
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            Row(
              children: [
                Expanded(
                  child: StudioDropdownButtonFormField<String>(
                    key: ValueKey<String>('${row.userId}-$pendingRole'),
                    initialValue: pendingRole,
                    decoration: InputDecoration(
                      labelText: l10n.projectMembersFieldUpdateRole,
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(value: 'viewer', child: Text(l10n.projectMembersRoleViewer)),
                      DropdownMenuItem(value: 'editor', child: Text(l10n.projectMembersRoleEditor)),
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
                const SizedBox(width: StudioSpacing.xs),
                StudioIconButton(
                  icon: saving ? Icons.hourglass_empty : Icons.save_outlined,
                  label: l10n.projectMembersTooltipSaveRole,
                  onPressed: saving || removing || pendingRole == row.role
                      ? null
                      : () => _saveRow(row.userId),
                ),
                StudioIconButton(
                  icon: removing ? Icons.hourglass_empty : Icons.delete_outline,
                  label: l10n.projectMembersTooltipRemoveAcl,
                  onPressed: saving || removing ? null : () => _remove(row.userId),
                  color: removing ? null : theme.colorScheme.error,
                ),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: StudioLayoutSpacing.inlineGap,
        vertical: StudioLayoutSpacing.microGap,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
        border: Border.all(color: studioPanelBorderColor(context)),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
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
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs, vertical: StudioSpacing.chromeActionGap),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
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
