import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';

import 'package:openflow_app/design_system/components/studio_collapsible_filter_panel.dart';
import 'package:openflow_app/design_system/studio_responsive_layout.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_filter_row.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/components/studio_text_styles.dart';
import 'package:openflow_app/design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../l10n/studio_code_labels.dart';
import '../rust_api.dart';
import 'controller.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';
import 'package:openflow_app/design_system/ix/studio_form_keyboard.dart';

class AdminConsoleSection extends StatefulWidget {
  const AdminConsoleSection({super.key, required this.controller});

  final AdminConsoleController controller;

  @override
  State<AdminConsoleSection> createState() => _AdminConsoleSectionState();
}

class _AdminConsoleSectionState extends State<AdminConsoleSection> {
  final _searchController = TextEditingController();
  final _opsReasonController = TextEditingController();
  final _opsNoteController = TextEditingController();
  final _dailyQuotaController = TextEditingController();
  final _workspaceOpsNoteController = TextEditingController();
  final _projectOpsNoteController = TextEditingController();
  final _workspaceMemberUserIdController = TextEditingController();
  final _workspaceOwnerUserIdController = TextEditingController();
  final _projectOwnerUserIdController = TextEditingController();
  final _workspaceBatchOpsNoteController = TextEditingController();
  String? _governanceDraftFingerprint;
  String? _workspaceGovernanceDraftFingerprint;
  String? _projectGovernanceDraftFingerprint;
  final Set<String> _selectedWorkspaceProjectIds = <String>{};
  AdminOperationalStatusV1 _operationalStatus = AdminOperationalStatusV1.active;
  AdminQuotaOverrideActionV1 _quotaAction = AdminQuotaOverrideActionV1.preserve;
  AdminWorkspaceLifecycleActionV1 _workspaceLifecycle =
      AdminWorkspaceLifecycleActionV1.preserve;
  AdminWorkspaceOpsNoteActionV1 _workspaceOpsNoteAction =
      AdminWorkspaceOpsNoteActionV1.preserve;
  AdminWorkspaceMemberRoleV1 _workspaceMemberRole =
      AdminWorkspaceMemberRoleV1.member;
  AdminProjectLifecycleActionV1 _projectLifecycle =
      AdminProjectLifecycleActionV1.preserve;
  AdminWorkspaceOpsNoteActionV1 _projectOpsNoteAction =
      AdminWorkspaceOpsNoteActionV1.preserve;
  AdminProjectLifecycleActionV1 _workspaceBatchLifecycle =
      AdminProjectLifecycleActionV1.preserve;
  AdminWorkspaceOpsNoteActionV1 _workspaceBatchOpsNoteAction =
      AdminWorkspaceOpsNoteActionV1.preserve;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant AdminConsoleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChanged);
      widget.controller.addListener(_handleChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    _searchController.dispose();
    _opsReasonController.dispose();
    _opsNoteController.dispose();
    _dailyQuotaController.dispose();
    _workspaceOpsNoteController.dispose();
    _projectOpsNoteController.dispose();
    _workspaceMemberUserIdController.dispose();
    _workspaceOwnerUserIdController.dispose();
    _projectOwnerUserIdController.dispose();
    _workspaceBatchOpsNoteController.dispose();
    super.dispose();
  }

  void _handleChanged() {
    _syncGovernanceDraft();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncGovernanceDraft() {
    final userDetail = widget.controller.userDetail;
    if (userDetail != null) {
      final fingerprint = [
        userDetail.userId,
        userDetail.operationalStatus,
        userDetail.operationalStatusReason ?? '',
        userDetail.opsNote ?? '',
        userDetail.dailyJobQuotaOverride?.toString() ?? '',
        userDetail.governanceAudit.length.toString(),
      ].join('|');
      if (fingerprint != _governanceDraftFingerprint) {
        _governanceDraftFingerprint = fingerprint;
        _operationalStatus = userDetail.operationalStatus == 'suspended'
            ? AdminOperationalStatusV1.suspended
            : AdminOperationalStatusV1.active;
        _opsReasonController.text = userDetail.operationalStatusReason ?? '';
        _opsNoteController.text = userDetail.opsNote ?? '';
        _dailyQuotaController.text =
            userDetail.dailyJobQuotaOverride?.toString() ?? '';
        _quotaAction = userDetail.dailyJobQuotaOverride == null
            ? AdminQuotaOverrideActionV1.preserve
            : AdminQuotaOverrideActionV1.set;
      }
      _workspaceGovernanceDraftFingerprint = null;
      _projectGovernanceDraftFingerprint = null;
      return;
    }
    _governanceDraftFingerprint = null;

    final workspaceDetail = widget.controller.workspaceDetail;
    if (workspaceDetail != null) {
      final fingerprint = [
        workspaceDetail.workspaceId,
        workspaceDetail.archivedAt ?? '',
        workspaceDetail.opsNote ?? '',
        workspaceDetail.governanceAudit.length.toString(),
        workspaceDetail.workspaceType,
      ].join('|');
      if (fingerprint != _workspaceGovernanceDraftFingerprint) {
        _workspaceGovernanceDraftFingerprint = fingerprint;
        _workspaceOpsNoteController.text = workspaceDetail.opsNote ?? '';
        _workspaceLifecycle = AdminWorkspaceLifecycleActionV1.preserve;
        _workspaceOpsNoteAction = AdminWorkspaceOpsNoteActionV1.preserve;
        _workspaceBatchOpsNoteController.clear();
        _workspaceBatchLifecycle = AdminProjectLifecycleActionV1.preserve;
        _workspaceBatchOpsNoteAction = AdminWorkspaceOpsNoteActionV1.preserve;
        _selectedWorkspaceProjectIds.clear();
      }
      _projectGovernanceDraftFingerprint = null;
      return;
    }
    _workspaceGovernanceDraftFingerprint = null;

    final projectDetail = widget.controller.projectDetail;
    if (projectDetail != null) {
      final fingerprint = [
        projectDetail.projectId,
        projectDetail.archivedAt ?? '',
        projectDetail.opsNote ?? '',
        projectDetail.governanceAudit.length.toString(),
      ].join('|');
      if (fingerprint != _projectGovernanceDraftFingerprint) {
        _projectGovernanceDraftFingerprint = fingerprint;
        _projectOpsNoteController.text = projectDetail.opsNote ?? '';
        _projectLifecycle = AdminProjectLifecycleActionV1.preserve;
        _projectOpsNoteAction = AdminWorkspaceOpsNoteActionV1.preserve;
      }
      return;
    }
    _projectGovernanceDraftFingerprint = null;
  }

  bool get _statusRequiresReason =>
      _operationalStatus == AdminOperationalStatusV1.suspended;

  bool get _quotaRequiresValue =>
      _quotaAction == AdminQuotaOverrideActionV1.set;

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
            Text(
              l10n.adminConsoleTitle,
              style: studioPaneTitleStyle(context),
            ),
            const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
            Text(
              l10n.adminConsoleIntro,
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
    final result = widget.controller.searchResult;
    return Padding(
      padding: const EdgeInsets.only(top: StudioSpacing.sm),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildStudioHeader(context, l10n),
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            DecoratedBox(
              decoration: studioInsetPanelDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(StudioSpacing.sm),
                child: StudioCollapsibleFilterPanel(
              collapsible: true,
              title: l10n.adminConsoleSearchLabel,
              subtitle: _searchController.text.trim().isNotEmpty
                  ? _searchController.text.trim()
                  : null,
              child: StudioFormKeyboardScope(
                onEnterSubmit: widget.controller.searching
                    ? null
                    : () => widget.controller.search(_searchController.text),
                child: StudioFilterRow(
                  wideLayout: StudioFilterWideLayout.toolbarRow,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: widget.controller.search,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.adminConsoleSearchLabel,
                          hintText: l10n.adminConsoleSearchHint,
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      style: studioFormIconLabeledButtonStyle(context),
                      onPressed: widget.controller.searching
                          ? null
                          : () => widget.controller.search(
                              _searchController.text,
                            ),
                      icon: widget.controller.searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore_outlined),
                      label: Text(l10n.adminConsoleSearchAction),
                    ),
                    if (widget.controller.selectedKind != null)
                      TextButton.icon(
                        style: studioFormTextButtonIconStyle(context),
                        onPressed: widget.controller.clearDetail,
                        icon: const Icon(Icons.layers_clear_outlined),
                        label: Text(l10n.adminConsoleClearDetailAction),
                      ),
                  ],
                ),
              ),
                ),
              ),
            ),
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            LayoutBuilder(
              builder: (context, constraints) {
                final split = studioUseThreePaneLayout(constraints.maxWidth);
                final searchColumn = widget.controller.searching && result == null
                    ? const StudioListSkeleton(
                        itemCount: 5,
                        scrollable: false,
                        padding: EdgeInsets.symmetric(
                          vertical: StudioSpacing.xs,
                        ),
                      )
                    : result == null
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildSearchGroup(
                            context,
                            title: l10n.adminConsoleGroupUsers,
                            emptyText: l10n.adminConsoleEmptyUsers,
                            children: result.users
                                .map((item) => _userHitTile(context, item))
                                .toList(growable: false),
                          ),
                          const SizedBox(height: StudioLayoutSpacing.insetDense),
                          _buildSearchGroup(
                            context,
                            title: l10n.adminConsoleGroupWorkspaces,
                            emptyText: l10n.adminConsoleEmptyWorkspaces,
                            children: result.workspaces
                                .map((item) => _workspaceHitTile(context, item))
                                .toList(growable: false),
                          ),
                          const SizedBox(height: StudioLayoutSpacing.insetDense),
                          _buildSearchGroup(
                            context,
                            title: l10n.adminConsoleGroupProjects,
                            emptyText: l10n.adminConsoleEmptyProjects,
                            children: result.projects
                                .map((item) => _projectHitTile(context, item))
                                .toList(growable: false),
                          ),
                          const SizedBox(height: StudioLayoutSpacing.insetDense),
                          _buildSearchGroup(
                            context,
                            title: l10n.adminConsoleGroupJobs,
                            emptyText: l10n.adminConsoleEmptyJobs,
                            children: result.jobs
                                .map((item) => _jobTile(context, item))
                                .toList(growable: false),
                          ),
                        ],
                      );
                final detailPanel = StudioAsyncDataView(
                  loading: widget.controller.loadingDetail,
                  loadingPlaceholder: StudioLoadingPlaceholder.pane,
                  scrollableLoading: false,
                  child: widget.controller.userDetail != null
                      ? _buildUserDetail(
                          context,
                          widget.controller.userDetail!,
                        )
                      : widget.controller.workspaceDetail != null
                      ? _buildWorkspaceDetail(
                          context,
                          widget.controller.workspaceDetail!,
                        )
                      : widget.controller.projectDetail != null
                      ? _buildProjectDetail(
                          context,
                          widget.controller.projectDetail!,
                        )
                      : const SizedBox.shrink(),
                );
                if (split && searchColumn != null) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 2, child: searchColumn),
                        const SizedBox(width: StudioLayoutSpacing.section),
                        Expanded(flex: 3, child: detailPanel),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (searchColumn != null) ...<Widget>[
                      searchColumn,
                      const SizedBox(height: StudioLayoutSpacing.stackMedium),
                    ],
                    detailPanel,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchGroup(
    BuildContext context, {
    required String title,
    required String emptyText,
    required List<Widget> children,
  }) {
    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: studioCardTitleStyle(context)),
            const SizedBox(height: StudioSpacing.xs),
            if (children.isEmpty)
              StudioEmptyState.emptyData(
                title: emptyText,
                icon: Icons.manage_search_outlined,
              )
            else
              ...studioStaggeredChildren(
                children,
                entranceKey: children.length,
              ),
          ],
        ),
      ),
    );
  }

  Widget _userHitTile(BuildContext context, AdminUserSearchHitV1 item) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return StudioListRow(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item.email ?? item.userId),
      subtitle: Text(
        l10n.adminConsoleUserHitSummary(
          item.planTier ?? 'free',
          item.operationalStatus,
          item.workspaceCount,
          item.projectCount,
          item.activeJobCount,
        ),
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => widget.controller.loadUser(item.userId),
    );
  }

  Widget _workspaceHitTile(
    BuildContext context,
    AdminWorkspaceSearchHitV1 item,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return StudioListRow(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        l10n.adminConsoleWorkspaceHitSummary(
          item.workspaceType,
          item.memberCount,
          item.projectCount,
          item.activeJobCount,
          item.archivedAt == null ? '' : l10n.adminConsoleArchivedSuffix,
        ),
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => widget.controller.loadWorkspace(item.workspaceId),
    );
  }

  Widget _projectHitTile(BuildContext context, AdminProjectSearchHitV1 item) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return StudioListRow(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.name?.trim().isNotEmpty == true
            ? item.name!
            : '#${item.numericId}',
      ),
      subtitle: Text(
        l10n.adminConsoleProjectHitSummary(
          item.numericId,
          item.workspaceName ?? l10n.adminConsoleNoWorkspace,
          item.ownerEmail ?? item.ownerUserId,
          item.archivedAt == null ? '' : l10n.adminConsoleArchivedSuffix,
        ),
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => widget.controller.loadProject(item.projectId),
    );
  }

  Widget _jobTile(BuildContext context, AdminJobSummaryV1 item) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return StudioListRow(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(studioJobListTitle(l10n, item.kind, item.status)),
      subtitle: Text(
        l10n.adminConsoleJobHitSummary(
          item.ownerEmail ?? item.ownerUserId,
          item.projectNumericId?.toString() ?? '-',
          _fmt(item.createdAt),
        ),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildUserDetail(
    BuildContext context,
    AdminUserDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return _detailCard(
      context,
      title: detail.email ?? detail.userId,
      chips: [
        l10n.adminConsoleChipPlan(detail.planTier),
        l10n.adminConsoleChipWorkspace(detail.workspaceCount),
        l10n.adminConsoleChipProject(detail.projectCount),
        l10n.adminConsoleChipActiveJob(detail.activeJobCount),
        l10n.adminConsoleChipApiKey(detail.apiKeyCount),
        l10n.adminConsoleChipUnreadNotif(detail.unreadNotificationCount),
      ],
      sections: [
        _kvWrap(context, {
          'userId': detail.userId,
          'createdAt': _fmt(detail.createdAt),
          'operationalStatus': detail.operationalStatus,
          'billingProvider': detail.billingProvider ?? '-',
          'subscription': detail.subscriptionStatus ?? '-',
          'currentWorkspace': detail.currentWorkspace?.name ?? '-',
        }),
        _buildWorkspaceContextPanel(context, detail),
        _buildGovernancePanel(context, detail),
        _subList(
          context,
          title: l10n.adminConsoleSectionMemberships,
          items: detail.memberships
              .map(
                (item) => l10n.adminConsoleMembershipItem(
                  item.workspaceName,
                  item.workspaceType,
                  item.role,
                  item.archivedAt == null
                      ? ''
                      : l10n.adminConsoleArchivedSuffix,
                ),
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: l10n.adminConsoleSectionRecentJobs,
          items: detail.recentJobs
              .map(
                (job) => l10n.adminConsoleRecentJobItem(
                  studioJobKindLabel(l10n, job.kind),
                  studioJobStatusLabel(l10n, job.status),
                  _jobProjectScopeLabel(job),
                  _fmt(job.createdAt),
                ),
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: l10n.adminConsoleSectionGovernanceAudit,
          items: detail.governanceAudit
              .map(
                (item) => l10n.adminConsoleAuditListItem(
                  _fmt(item.createdAt),
                  item.actorLabel,
                  _auditSummary(context, item),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildGovernancePanel(
    BuildContext context,
    AdminUserDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleGovernanceActionsTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            StudioChoiceChip(
              label: Text(l10n.adminConsoleStatusActive),
              selected: _operationalStatus == AdminOperationalStatusV1.active,
              onSelected: (_) {
                setState(() {
                  _operationalStatus = AdminOperationalStatusV1.active;
                  _opsReasonController.clear();
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleStatusSuspended),
              selected:
                  _operationalStatus == AdminOperationalStatusV1.suspended,
              onSelected: (_) {
                setState(() {
                  _operationalStatus = AdminOperationalStatusV1.suspended;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: _opsReasonController,
          enabled: _statusRequiresReason,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.adminConsoleSuspendReasonLabel,
            hintText: _statusRequiresReason
                ? l10n.adminConsoleSuspendReasonHint
                : l10n.adminConsoleSuspendReasonDisabledHint,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: _opsNoteController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.adminConsoleInternalNoteLabel,
            hintText: l10n.adminConsoleInternalNoteHint,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        Text(
          l10n.adminConsoleDailyQuotaOverrideTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          detail.dailyJobQuotaOverride == null
              ? l10n.adminConsoleDailyQuotaNotOverridden
              : l10n.adminConsoleDailyQuotaCurrentOverride(
                  detail.dailyJobQuotaOverride!,
                ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            StudioChoiceChip(
              label: Text(l10n.adminConsoleQuotaActionPreserve),
              selected: _quotaAction == AdminQuotaOverrideActionV1.preserve,
              onSelected: (_) {
                setState(() {
                  _quotaAction = AdminQuotaOverrideActionV1.preserve;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleQuotaActionClear),
              selected: _quotaAction == AdminQuotaOverrideActionV1.clear,
              onSelected: (_) {
                setState(() {
                  _quotaAction = AdminQuotaOverrideActionV1.clear;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleQuotaActionSet),
              selected: _quotaAction == AdminQuotaOverrideActionV1.set,
              onSelected: (_) {
                setState(() {
                  _quotaAction = AdminQuotaOverrideActionV1.set;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        SizedBox(
          width: studioAdaptiveFieldWidth(context, max: 280),
          child: TextField(
            controller: _dailyQuotaController,
            enabled: _quotaRequiresValue,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.adminConsoleDailyQuotaLabel,
              hintText: _quotaRequiresValue
                  ? (detail.dailyJobQuotaOverride?.toString() ??
                        l10n.adminConsoleDailyQuotaInputExample)
                  : l10n.adminConsoleDailyQuotaInputDisabledHint,
            ),
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        FilledButton.tonalIcon(
          style: studioFormIconLabeledButtonStyle(context),
          onPressed: widget.controller.savingGovernance
              ? null
              : () => widget.controller.updateUserGovernance(
                  userId: detail.userId,
                  operationalStatus: _operationalStatus,
                  operationalStatusReason:
                      _opsReasonController.text.trim().isEmpty
                      ? null
                      : _opsReasonController.text.trim(),
                  opsNote: _opsNoteController.text.trim().isEmpty
                      ? null
                      : _opsNoteController.text.trim(),
                  dailyJobQuotaAction: _quotaAction,
                  dailyJobQuota: _dailyQuotaController.text.trim().isEmpty
                      ? null
                      : int.tryParse(_dailyQuotaController.text.trim()),
                ),
          icon: widget.controller.savingGovernance
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.admin_panel_settings_outlined),
          label: Text(
            widget.controller.savingGovernance
                ? l10n.adminConsoleSaving
                : l10n.adminConsoleSaveGovernanceSettings,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceContextPanel(
    BuildContext context,
    AdminUserDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final currentWorkspaceId = detail.currentWorkspace?.workspaceId;
    final personalMembership = detail.memberships
        .where((item) {
          return item.workspaceType == 'personal';
        })
        .toList(growable: false);
    final switchTargets = detail.memberships
        .where((item) {
          return item.archivedAt == null &&
              item.workspaceId != currentWorkspaceId;
        })
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleWorkspaceContextRepairTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.adminConsoleWorkspaceContextRepairIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            OutlinedButton.icon(
              style: studioFormOutlinedIconLabeledButtonStyle(context),
              onPressed: widget.controller.savingWorkspaceContext
                  ? null
                  : () => widget.controller.updateUserWorkspaceContext(
                      userId: detail.userId,
                      action: AdminUserWorkspaceContextActionV1.resetToPersonal,
                    ),
              icon: const Icon(Icons.home_outlined),
              label: Text(
                personalMembership.isEmpty
                    ? l10n.adminConsoleWorkspaceContextRebuildAndSwitchPersonal
                    : l10n.adminConsoleWorkspaceContextSwitchPersonal,
              ),
            ),
            ...studioStaggeredChildren(
              switchTargets.map(
                (item) => OutlinedButton(
                  style: studioFormSecondaryButtonStyle(context),
                  onPressed:
                      widget.controller.savingWorkspaceContext
                          ? null
                          : () =>
                              widget.controller.updateUserWorkspaceContext(
                                userId: detail.userId,
                                action:
                                    AdminUserWorkspaceContextActionV1.setToWorkspace,
                                workspaceId: item.workspaceId,
                              ),
                  child: Text(
                    l10n.adminConsoleWorkspaceContextSwitchTo(
                      item.workspaceName,
                    ),
                  ),
                ),
              ),
              entranceKey: switchTargets.length,
            ),
          ],
        ),
        if (widget.controller.savingWorkspaceContext) ...[
          const SizedBox(height: StudioSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: StudioSpacing.xs),
              Text(
                l10n.adminConsoleWorkspaceContextRepairing,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  bool get _workspaceOpsNoteRequiresValue =>
      _workspaceOpsNoteAction == AdminWorkspaceOpsNoteActionV1.set;

  Widget _buildWorkspaceGovernancePanel(
    BuildContext context,
    AdminWorkspaceDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final isPersonal = detail.workspaceType == 'personal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleWorkspaceGovernanceTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        if (isPersonal)
          Text(
            l10n.adminConsoleWorkspaceGovernancePersonalHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          )
        else
          Text(
            l10n.adminConsoleWorkspaceGovernanceEnterpriseHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          ),
        const SizedBox(height: StudioSpacing.xs),
        if (!isPersonal) ...[
          Wrap(
            spacing: StudioSpacing.xs,
            runSpacing: StudioSpacing.xs,
            children: [
              StudioChoiceChip(
                label: Text(l10n.adminConsoleLifecyclePreserve),
                selected:
                    _workspaceLifecycle ==
                    AdminWorkspaceLifecycleActionV1.preserve,
                onSelected: (_) {
                  setState(() {
                    _workspaceLifecycle =
                        AdminWorkspaceLifecycleActionV1.preserve;
                  });
                },
              ),
              StudioChoiceChip(
                label: Text(l10n.adminConsoleLifecycleArchive),
                selected:
                    _workspaceLifecycle ==
                    AdminWorkspaceLifecycleActionV1.archive,
                onSelected: (_) {
                  setState(() {
                    _workspaceLifecycle =
                        AdminWorkspaceLifecycleActionV1.archive;
                  });
                },
              ),
              StudioChoiceChip(
                label: Text(l10n.adminConsoleLifecycleRestore),
                selected:
                    _workspaceLifecycle ==
                    AdminWorkspaceLifecycleActionV1.restore,
                onSelected: (_) {
                  setState(() {
                    _workspaceLifecycle =
                        AdminWorkspaceLifecycleActionV1.restore;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: StudioSpacing.xs),
        ],
        Text(
          l10n.adminConsoleInternalNoteLabel,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            StudioChoiceChip(
              label: Text(l10n.adminConsoleNoteActionPreserve),
              selected:
                  _workspaceOpsNoteAction ==
                  AdminWorkspaceOpsNoteActionV1.preserve,
              onSelected: (_) {
                setState(() {
                  _workspaceOpsNoteAction =
                      AdminWorkspaceOpsNoteActionV1.preserve;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleNoteActionClear),
              selected:
                  _workspaceOpsNoteAction ==
                  AdminWorkspaceOpsNoteActionV1.clear,
              onSelected: (_) {
                setState(() {
                  _workspaceOpsNoteAction = AdminWorkspaceOpsNoteActionV1.clear;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleNoteActionSet),
              selected:
                  _workspaceOpsNoteAction == AdminWorkspaceOpsNoteActionV1.set,
              onSelected: (_) {
                setState(() {
                  _workspaceOpsNoteAction = AdminWorkspaceOpsNoteActionV1.set;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: _workspaceOpsNoteController,
          enabled: _workspaceOpsNoteRequiresValue,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.adminConsoleInternalNoteBodyLabel,
            hintText: _workspaceOpsNoteRequiresValue
                ? l10n.adminConsoleInternalNoteBodySubmitHint
                : l10n.adminConsoleInternalNoteBodyEditableHint,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        FilledButton.tonalIcon(
          style: studioFormIconLabeledButtonStyle(context),
          onPressed: widget.controller.savingGovernance
              ? null
              : () => widget.controller.updateWorkspaceGovernance(
                  workspaceId: detail.workspaceId,
                  workspaceLifecycle: isPersonal
                      ? AdminWorkspaceLifecycleActionV1.preserve
                      : _workspaceLifecycle,
                  opsNoteAction: _workspaceOpsNoteAction,
                  opsNote: _workspaceOpsNoteController.text,
                ),
          icon: widget.controller.savingGovernance
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.domain_verification_outlined),
          label: Text(
            widget.controller.savingGovernance
                ? l10n.adminConsoleSaving
                : l10n.adminConsoleSaveGovernance,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceMemberRemediationPanel(
    BuildContext context,
    AdminWorkspaceDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleWorkspaceMemberRemediationTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.adminConsoleWorkspaceMemberRemediationHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            SizedBox(
              width: studioAdaptiveFieldWidth(context),
              child: TextField(
                controller: _workspaceMemberUserIdController,
                decoration: InputDecoration(
                  labelText: l10n.adminConsoleMemberUserIdLabel,
                  hintText: l10n.adminConsoleMemberUserIdHint,
                ),
              ),
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleRoleMember),
              selected:
                  _workspaceMemberRole == AdminWorkspaceMemberRoleV1.member,
              onSelected: (_) {
                setState(() {
                  _workspaceMemberRole = AdminWorkspaceMemberRoleV1.member;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleRoleAdmin),
              selected:
                  _workspaceMemberRole == AdminWorkspaceMemberRoleV1.admin,
              onSelected: (_) {
                setState(() {
                  _workspaceMemberRole = AdminWorkspaceMemberRoleV1.admin;
                });
              },
            ),
            FilledButton.tonalIcon(
              style: studioFormIconLabeledButtonStyle(context),
              onPressed: widget.controller.savingWorkspaceMembership
                  ? null
                  : () => widget.controller.updateWorkspaceMemberRemediation(
                      workspaceId: detail.workspaceId,
                      action: AdminWorkspaceMemberRemediationActionV1.upsert,
                      userId: _workspaceMemberUserIdController.text,
                      role: _workspaceMemberRole,
                    ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(
                widget.controller.savingWorkspaceMembership
                    ? l10n.adminConsoleProcessing
                    : l10n.adminConsoleUpsertMemberAction,
              ),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.sm),
        ...detail.members.toList().asMap().entries.map((entry) {
          final member = entry.value;
          final isOwner = member.role == 'owner';
          return studioStaggeredItem(
            entry.key,
            entranceKey: detail.members.length,
            child: Padding(
            padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
            child: StudioDenseActionRow(
              spacing: StudioSpacing.xs,
              children: [
                Text(
                  '${member.email ?? member.userId} · ${member.role}',
                  style: theme.textTheme.bodySmall,
                ),
                if (!isOwner) ...[
                  OutlinedButton(
                    style: studioFormSecondaryButtonStyle(context),
                    onPressed: widget.controller.savingWorkspaceMembership
                        ? null
                        : () => widget.controller
                              .updateWorkspaceMemberRemediation(
                                workspaceId: detail.workspaceId,
                                action: AdminWorkspaceMemberRemediationActionV1
                                    .upsert,
                                userId: member.userId,
                                role: AdminWorkspaceMemberRoleV1.member,
                              ),
                    child: Text(l10n.adminConsoleSetAsMember),
                  ),
                  OutlinedButton(
                    style: studioFormSecondaryButtonStyle(context),
                    onPressed: widget.controller.savingWorkspaceMembership
                        ? null
                        : () => widget.controller
                              .updateWorkspaceMemberRemediation(
                                workspaceId: detail.workspaceId,
                                action: AdminWorkspaceMemberRemediationActionV1
                                    .upsert,
                                userId: member.userId,
                                role: AdminWorkspaceMemberRoleV1.admin,
                              ),
                    child: Text(l10n.adminConsoleSetAsAdmin),
                  ),
                  OutlinedButton(
                    style: studioFormSecondaryButtonStyle(context),
                    onPressed: widget.controller.savingWorkspaceMembership
                        ? null
                        : () => widget.controller
                              .updateWorkspaceMemberRemediation(
                                workspaceId: detail.workspaceId,
                                action: AdminWorkspaceMemberRemediationActionV1
                                    .remove,
                                userId: member.userId,
                              ),
                    child: Text(l10n.adminConsoleRemoveAction),
                  ),
                ] else
                  Text(
                    l10n.adminConsoleOwnerTransferHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: StudioTokens.of(context).textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          );
        }),
      ],
    );
  }

  Widget _buildWorkspaceOwnerTransferPanel(
    BuildContext context,
    AdminWorkspaceDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final isPersonal = detail.workspaceType == 'personal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleWorkspaceOwnerRemediationTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          isPersonal
              ? l10n.adminConsoleWorkspaceOwnerRemediationPersonalHint
              : l10n.adminConsoleWorkspaceOwnerRemediationHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
        if (!isPersonal) ...[
          const SizedBox(height: StudioSpacing.xs),
          StudioDenseActionRow(
            spacing: StudioSpacing.xs,
            children: [
              SizedBox(
                width: studioAdaptiveFieldWidth(context),
                child: TextField(
                  controller: _workspaceOwnerUserIdController,
                  decoration: InputDecoration(
                    labelText: l10n.adminConsoleTargetOwnerUserIdLabel,
                    hintText: l10n.adminConsoleTargetOwnerUserIdHint,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                style: studioFormIconLabeledButtonStyle(context),
                onPressed: widget.controller.savingOwnershipRemediation
                    ? null
                    : () => widget.controller.transferWorkspaceOwner(
                        workspaceId: detail.workspaceId,
                        targetUserId: _workspaceOwnerUserIdController.text,
                      ),
                icon: const Icon(Icons.swap_horiz_outlined),
                label: Text(
                  widget.controller.savingOwnershipRemediation
                      ? l10n.adminConsoleProcessing
                      : l10n.adminConsoleTransferOwnerAction,
                ),
              ),
            ],
          ),
          const SizedBox(height: StudioSpacing.sm),
          ...detail.members
              .where((member) => member.role != 'owner')
              .map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                  child: StudioDenseActionRow(
                    spacing: StudioSpacing.xs,
                    children: [
                      Text(
                        '${member.email ?? member.userId} · ${member.role}',
                        style: theme.textTheme.bodySmall,
                      ),
                      OutlinedButton(
                        style: studioFormSecondaryButtonStyle(context),
                        onPressed: widget.controller.savingOwnershipRemediation
                            ? null
                            : () => widget.controller.transferWorkspaceOwner(
                                workspaceId: detail.workspaceId,
                                targetUserId: member.userId,
                              ),
                        child: Text(l10n.adminConsoleSetAsOwner),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildWorkspaceAclPanel(
    BuildContext context,
    AdminWorkspaceDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final breakdown = detail.workspaceRoleBreakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleAclSummaryTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            StudioChip(
              label: Text(
                l10n.adminConsoleRoleCountOwner(breakdown['owner'] ?? 0),
              ),
            ),
            StudioChip(
              label: Text(
                l10n.adminConsoleRoleCountAdmin(breakdown['admin'] ?? 0),
              ),
            ),
            StudioChip(
              label: Text(
                l10n.adminConsoleRoleCountMember(breakdown['member'] ?? 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        if (detail.projectAclSummaries.isEmpty)
          StudioEmptyState.emptyData(
            title: l10n.adminConsoleNoProjectAclSummary,
            icon: Icons.shield_outlined,
          )
        else
          ...studioStaggeredChildren(
            detail.projectAclSummaries.map(
              (project) => Padding(
                padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                child: Wrap(
                  spacing: StudioSpacing.xs,
                  runSpacing: StudioSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Checkbox(
                      value: _selectedWorkspaceProjectIds.contains(
                        project.projectId,
                      ),
                      onChanged: widget.controller.savingBatchGovernance
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedWorkspaceProjectIds.add(
                                    project.projectId,
                                  );
                                } else {
                                  _selectedWorkspaceProjectIds.remove(
                                    project.projectId,
                                  );
                                }
                              });
                            },
                    ),
                    Text(
                      '#${project.numericId} ${project.name ?? ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    StudioChip(label: Text(studioAdminAclModeLabel(l10n, project.aclMode))),
                    StudioChip(
                      label: Text(
                        l10n.adminConsoleExplicitAclCount(
                          project.explicitAclCount,
                        ),
                      ),
                    ),
                    StudioChip(
                      label: Text(
                        l10n.adminConsoleEditorCount(project.editorCount),
                      ),
                    ),
                    StudioChip(
                      label: Text(
                        l10n.adminConsoleViewerCount(project.viewerCount),
                      ),
                    ),
                    if (project.archivedAt != null)
                      StudioChip(label: Text(l10n.teamWorkspaceArchivedBadge)),
                    TextButton(
                      onPressed: () =>
                          widget.controller.loadProject(project.projectId),
                      child: Text(l10n.adminConsoleViewAction),
                    ),
                  ],
                ),
              ),
            ),
            entranceKey: detail.projectAclSummaries.length,
          ),
      ],
    );
  }

  Widget _buildWorkspaceProjectBatchGovernancePanel(
    BuildContext context,
    AdminWorkspaceDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleBatchProjectGovernanceTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.adminConsoleBatchProjectGovernanceHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            StudioChoiceChip(
              label: Text(l10n.adminConsoleBatchLifecyclePreserve),
              selected:
                  _workspaceBatchLifecycle ==
                  AdminProjectLifecycleActionV1.preserve,
              onSelected: (_) {
                setState(() {
                  _workspaceBatchLifecycle =
                      AdminProjectLifecycleActionV1.preserve;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleBatchLifecycleArchive),
              selected:
                  _workspaceBatchLifecycle ==
                  AdminProjectLifecycleActionV1.archive,
              onSelected: (_) {
                setState(() {
                  _workspaceBatchLifecycle =
                      AdminProjectLifecycleActionV1.archive;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleBatchLifecycleRestore),
              selected:
                  _workspaceBatchLifecycle ==
                  AdminProjectLifecycleActionV1.restore,
              onSelected: (_) {
                setState(() {
                  _workspaceBatchLifecycle =
                      AdminProjectLifecycleActionV1.restore;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            StudioChoiceChip(
              label: Text(l10n.adminConsoleBatchNotePreserve),
              selected:
                  _workspaceBatchOpsNoteAction ==
                  AdminWorkspaceOpsNoteActionV1.preserve,
              onSelected: (_) {
                setState(() {
                  _workspaceBatchOpsNoteAction =
                      AdminWorkspaceOpsNoteActionV1.preserve;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleBatchNoteClear),
              selected:
                  _workspaceBatchOpsNoteAction ==
                  AdminWorkspaceOpsNoteActionV1.clear,
              onSelected: (_) {
                setState(() {
                  _workspaceBatchOpsNoteAction =
                      AdminWorkspaceOpsNoteActionV1.clear;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleBatchNoteSet),
              selected:
                  _workspaceBatchOpsNoteAction ==
                  AdminWorkspaceOpsNoteActionV1.set,
              onSelected: (_) {
                setState(() {
                  _workspaceBatchOpsNoteAction =
                      AdminWorkspaceOpsNoteActionV1.set;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: _workspaceBatchOpsNoteController,
          enabled: _workspaceBatchOpsNoteRequiresValue,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.adminConsoleBatchNoteBodyLabel,
            hintText: _workspaceBatchOpsNoteRequiresValue
                ? l10n.adminConsoleBatchNoteBodySubmitHint
                : l10n.adminConsoleBatchNoteBodyEditableHint,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        FilledButton.tonalIcon(
          style: studioFormIconLabeledButtonStyle(context),
          onPressed: widget.controller.savingBatchGovernance
              ? null
              : () async {
                  final response = await widget.controller
                      .updateProjectBatchGovernance(
                        projectIds: _selectedWorkspaceProjectIds.toList(
                          growable: false,
                        ),
                        projectLifecycle: _workspaceBatchLifecycle,
                        opsNoteAction: _workspaceBatchOpsNoteAction,
                        opsNote: _workspaceBatchOpsNoteController.text,
                      );
                  if (!mounted || response == null) {
                    return;
                  }
                  setState(() {
                    _selectedWorkspaceProjectIds.clear();
                  });
                },
          icon: widget.controller.savingBatchGovernance
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.playlist_add_check_circle_outlined),
          label: Text(
            widget.controller.savingBatchGovernance
                ? l10n.adminConsoleProcessing
                : l10n.adminConsoleBatchApplyAction(
                    _selectedWorkspaceProjectIds.length,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceDetail(
    BuildContext context,
    AdminWorkspaceDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return _detailCard(
      context,
      title: detail.name,
      chips: [
        detail.workspaceType,
        l10n.adminConsoleChipMember(detail.memberCount),
        l10n.adminConsoleChipProject(detail.projectCount),
        l10n.adminConsoleChipActiveJob(detail.activeJobCount),
        if (detail.archivedAt != null) l10n.adminConsoleArchivedLabel,
      ],
      sections: [
        _kvWrap(context, {
          'workspaceId': detail.workspaceId,
          'owner': detail.ownerEmail ?? detail.ownerUserId,
          'archivedAt': detail.archivedAt == null
              ? '-'
              : _fmt(detail.archivedAt!),
          'opsNote': detail.opsNote == null || detail.opsNote!.trim().isEmpty
              ? '-'
              : detail.opsNote!,
        }),
        _buildWorkspaceGovernancePanel(context, detail),
        _buildWorkspaceOwnerTransferPanel(context, detail),
        _buildWorkspaceMemberRemediationPanel(context, detail),
        _buildWorkspaceAclPanel(context, detail),
        _buildWorkspaceProjectBatchGovernancePanel(context, detail),
        _subList(
          context,
          title: l10n.adminConsoleSectionMembers,
          items: detail.members
              .map(
                (item) => l10n.adminConsoleMemberListItem(
                  item.email ?? item.userId,
                  item.role,
                  _fmt(item.createdAt),
                ),
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: l10n.adminConsoleSectionRecentProjects,
          items: detail.recentProjects
              .map(
                (item) => l10n.adminConsoleRecentProjectItem(
                  item.numericId,
                  item.name ?? '',
                  item.ownerEmail ?? item.ownerUserId,
                ),
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: l10n.adminConsoleSectionRecentJobs,
          items: detail.recentJobs
              .map(
                (job) => l10n.adminConsoleRecentJobItem(
                  studioJobKindLabel(l10n, job.kind),
                  studioJobStatusLabel(l10n, job.status),
                  _jobProjectScopeLabel(job),
                  _fmt(job.createdAt),
                ),
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: l10n.adminConsoleSectionGovernanceAudit,
          items: detail.governanceAudit
              .map(
                (item) => l10n.adminConsoleAuditListItem(
                  _fmt(item.createdAt),
                  item.actorLabel,
                  _workspaceAuditSummary(context, item),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  bool get _projectOpsNoteRequiresValue =>
      _projectOpsNoteAction == AdminWorkspaceOpsNoteActionV1.set;

  bool get _workspaceBatchOpsNoteRequiresValue =>
      _workspaceBatchOpsNoteAction == AdminWorkspaceOpsNoteActionV1.set;

  Widget _buildProjectOwnerTransferPanel(
    BuildContext context,
    AdminProjectDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleProjectOwnerRemediationTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.adminConsoleProjectOwnerRemediationHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: studioAdaptiveFieldWidth(context),
              child: TextField(
                controller: _projectOwnerUserIdController,
                decoration: InputDecoration(
                  labelText: l10n.adminConsoleTargetOwnerUserIdLabel,
                  hintText: l10n.adminConsoleTargetProjectOwnerUserIdHint,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              style: studioFormIconLabeledButtonStyle(context),
              onPressed: widget.controller.savingOwnershipRemediation
                  ? null
                  : () => widget.controller.transferProjectOwner(
                      projectId: detail.projectId,
                      targetUserId: _projectOwnerUserIdController.text,
                    ),
              icon: const Icon(Icons.swap_horizontal_circle_outlined),
              label: Text(
                widget.controller.savingOwnershipRemediation
                    ? l10n.adminConsoleProcessing
                    : l10n.adminConsoleRepairProjectOwnerAction,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectGovernancePanel(
    BuildContext context,
    AdminProjectDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.adminConsoleProjectGovernanceTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.adminConsoleProjectGovernanceHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            StudioChoiceChip(
              label: Text(l10n.adminConsoleLifecyclePreserve),
              selected:
                  _projectLifecycle == AdminProjectLifecycleActionV1.preserve,
              onSelected: (_) {
                setState(() {
                  _projectLifecycle = AdminProjectLifecycleActionV1.preserve;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleLifecycleArchive),
              selected:
                  _projectLifecycle == AdminProjectLifecycleActionV1.archive,
              onSelected: (_) {
                setState(() {
                  _projectLifecycle = AdminProjectLifecycleActionV1.archive;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleLifecycleRestore),
              selected:
                  _projectLifecycle == AdminProjectLifecycleActionV1.restore,
              onSelected: (_) {
                setState(() {
                  _projectLifecycle = AdminProjectLifecycleActionV1.restore;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.adminConsoleInternalNoteLabel,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            StudioChoiceChip(
              label: Text(l10n.adminConsoleNoteActionPreserve),
              selected:
                  _projectOpsNoteAction ==
                  AdminWorkspaceOpsNoteActionV1.preserve,
              onSelected: (_) {
                setState(() {
                  _projectOpsNoteAction =
                      AdminWorkspaceOpsNoteActionV1.preserve;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleNoteActionClear),
              selected:
                  _projectOpsNoteAction == AdminWorkspaceOpsNoteActionV1.clear,
              onSelected: (_) {
                setState(() {
                  _projectOpsNoteAction = AdminWorkspaceOpsNoteActionV1.clear;
                });
              },
            ),
            StudioChoiceChip(
              label: Text(l10n.adminConsoleNoteActionSet),
              selected:
                  _projectOpsNoteAction == AdminWorkspaceOpsNoteActionV1.set,
              onSelected: (_) {
                setState(() {
                  _projectOpsNoteAction = AdminWorkspaceOpsNoteActionV1.set;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: _projectOpsNoteController,
          enabled: _projectOpsNoteRequiresValue,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.adminConsoleInternalNoteBodyLabel,
            hintText: _projectOpsNoteRequiresValue
                ? l10n.adminConsoleInternalNoteBodySubmitHint
                : l10n.adminConsoleInternalNoteBodyEditableHint,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        FilledButton.tonalIcon(
          style: studioFormIconLabeledButtonStyle(context),
          onPressed: widget.controller.savingGovernance
              ? null
              : () => widget.controller.updateProjectGovernance(
                  projectId: detail.projectId,
                  projectLifecycle: _projectLifecycle,
                  opsNoteAction: _projectOpsNoteAction,
                  opsNote: _projectOpsNoteController.text,
                ),
          icon: widget.controller.savingGovernance
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_special_outlined),
          label: Text(
            widget.controller.savingGovernance
                ? l10n.adminConsoleSaving
                : l10n.adminConsoleSaveGovernance,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectDetail(
    BuildContext context,
    AdminProjectDetailResponseV1 detail,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return _detailCard(
      context,
      title: detail.name?.trim().isNotEmpty == true
          ? l10n.adminConsoleProjectTitleWithName(
              detail.name!,
              detail.numericId,
            )
          : l10n.adminConsoleProjectTitle(detail.numericId),
      chips: [
        l10n.adminConsoleChipScript(detail.scriptCount),
        l10n.adminConsoleChipAsset(detail.assetCount),
        l10n.adminConsoleChipJob(detail.jobCount),
        l10n.adminConsoleChipActiveJob(detail.activeJobCount),
        studioAdminAclModeLabel(l10n, detail.projectAclMode),
        l10n.adminConsoleExplicitAclCount(detail.explicitAclCount),
        if (detail.archivedAt != null) l10n.adminConsoleArchivedLabel,
      ],
      sections: [
        _kvWrap(context, {
          'projectId': detail.projectId,
          'owner': detail.ownerEmail ?? detail.ownerUserId,
          'workspace': detail.workspace?.name ?? '-',
          'projectArchivedAt': detail.archivedAt == null
              ? '-'
              : _fmt(detail.archivedAt!),
          'opsNote': detail.opsNote == null || detail.opsNote!.trim().isEmpty
              ? '-'
              : detail.opsNote!,
          'aclMode': detail.projectAclMode,
          'editorCount': '${detail.editorCount}',
          'viewerCount': '${detail.viewerCount}',
          'createdAt': detail.createdAt == null ? '-' : _fmt(detail.createdAt!),
          'updatedAt': detail.updatedAt == null ? '-' : _fmt(detail.updatedAt!),
        }),
        _buildProjectOwnerTransferPanel(context, detail),
        _buildProjectGovernancePanel(context, detail),
        _subList(
          context,
          title: l10n.adminConsoleSectionExplicitAclMembers,
          items: detail.aclMembers
              .map(
                (item) => l10n.adminConsoleAclMemberItem(
                  item.email ?? item.userId,
                  item.workspaceRole,
                  item.projectRole,
                  _fmt(item.updatedAt),
                ),
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: l10n.adminConsoleSectionWorkspaceCandidates,
          items: detail.workspaceMemberCandidates
              .map(
                (item) => l10n.adminConsoleWorkspaceCandidateItem(
                  item.email ?? item.userId,
                  item.workspaceRole,
                  item.explicitProjectRole ?? '-',
                ),
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: l10n.adminConsoleSectionRecentJobs,
          items: detail.recentJobs
              .map(
                (job) => l10n.adminConsoleProjectRecentJobItem(
                  studioJobKindLabel(l10n, job.kind),
                  studioJobStatusLabel(l10n, job.status),
                  job.ownerEmail ?? job.ownerUserId,
                  _fmt(job.createdAt),
                ),
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: l10n.adminConsoleSectionGovernanceAudit,
          items: detail.governanceAudit
              .map(
                (item) => l10n.adminConsoleAuditListItem(
                  _fmt(item.createdAt),
                  item.actorLabel,
                  _projectAuditSummary(context, item),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _detailCard(
    BuildContext context, {
    required String title,
    required List<String> chips,
    required List<Widget> sections,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: studioPanelBorderColor(context)),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: StudioSpacing.xs),
          Wrap(
            spacing: StudioSpacing.xs,
            runSpacing: StudioSpacing.xs,
            children: chips
                .map((item) => StudioChip(label: Text(item)))
                .toList(growable: false),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          ...sections
              .expand((widget) => [widget, const SizedBox(height: StudioSpacing.sm)])
              .toList()
            ..removeLast(),
        ],
      ),
    );
  }

  Widget _kvWrap(BuildContext context, Map<String, String> rows) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Wrap(
      spacing: StudioSpacing.xs,
      runSpacing: StudioSpacing.xs,
      children: rows.entries
          .map(
            (entry) => StudioChip(
              label: Text(l10n.l10nBatch_078b5e4699(_fieldLabel(l10n, entry.key), entry.value)),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _subList(
    BuildContext context, {
    required String title,
    required List<String> items,
  }) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: StudioSpacing.xs),
        if (items.isEmpty)
          StudioEmptyState.emptyData(
            title: l10n.adminConsoleNoData,
            icon: Icons.inbox_outlined,
          )
        else
          ...studioStaggeredChildren(
            items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(
                  bottom: StudioSpacing.chromeActionGap,
                ),
                child: Text(item, style: theme.textTheme.bodySmall),
              ),
            ),
            entranceKey: items.length,
          ),
      ],
    );
  }

  String _auditSummary(
    BuildContext context,
    AdminUserGovernanceAuditSummaryV1 item,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final nextStatus = item.nextState['operationalStatus'];
    final nextQuota = item.nextState['dailyJobQuotaOverride'];
    return l10n.adminConsoleAuditUserSummary(
      '$nextStatus',
      '${nextQuota ?? 'null'}',
    );
  }

  String _workspaceAuditSummary(
    BuildContext context,
    AdminWorkspaceGovernanceAuditSummaryV1 item,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final action = item.nextState['action'];
    if (action == 'upsert' || action == 'remove') {
      final targetUserId =
          item.nextState['targetUserId'] ?? item.previousState['targetUserId'];
      final targetRole =
          item.nextState['targetRole'] ?? item.previousState['targetRole'];
      final prunedProjectAclCount = item.nextState['prunedProjectAclCount'];
      final currentWorkspaceReset = item.nextState['currentWorkspaceReset'];
      return l10n.adminConsoleAuditWorkspaceMembership(
        '$action',
        '${targetUserId ?? '-'}',
        '${targetRole ?? '-'}',
        '${prunedProjectAclCount ?? 0}',
        '${currentWorkspaceReset ?? false}',
      );
    }
    final newOwnerUserId = item.nextState['newOwnerUserId'];
    if (newOwnerUserId != null) {
      final previousOwnerUserId = item.nextState['previousOwnerUserId'];
      return l10n.adminConsoleAuditOwnerTransfer(
        '${previousOwnerUserId ?? '-'}',
        '${newOwnerUserId ?? '-'}',
        '${item.nextState['targetRole'] ?? '-'}',
        '${item.nextState['currentWorkspaceReset'] ?? '-'}',
      );
    }
    final nextArchived = item.nextState['archivedAt'];
    final nextNote = item.nextState['opsNote'];
    return l10n.adminConsoleAuditArchiveNote(
      '$nextArchived',
      '${nextNote ?? 'null'}',
    );
  }

  String _projectAuditSummary(
    BuildContext context,
    AdminProjectGovernanceAuditSummaryV1 item,
  ) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final newOwnerUserId = item.nextState['newOwnerUserId'];
    if (newOwnerUserId != null) {
      final previousOwnerUserId = item.nextState['previousOwnerUserId'];
      final preservedAccess =
          item.nextState['preservedPreviousOwnerEditorAccess'];
      return l10n.adminConsoleAuditProjectOwnerTransfer(
        '${previousOwnerUserId ?? '-'}',
        '${newOwnerUserId ?? '-'}',
        '${preservedAccess ?? false}',
      );
    }
    final nextArchived = item.nextState['archivedAt'];
    final nextNote = item.nextState['opsNote'];
    return l10n.adminConsoleAuditArchiveNote(
      '$nextArchived',
      '${nextNote ?? 'null'}',
    );
  }

  String _fieldLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'userId':
        return l10n.adminConsoleFieldUserId;
      case 'createdAt':
        return l10n.adminConsoleFieldCreatedAt;
      case 'updatedAt':
        return l10n.adminConsoleFieldUpdatedAt;
      case 'operationalStatus':
        return l10n.adminConsoleFieldOperationalStatus;
      case 'billingProvider':
        return l10n.adminConsoleFieldBillingProvider;
      case 'subscription':
        return l10n.adminConsoleFieldSubscription;
      case 'currentWorkspace':
        return l10n.adminConsoleFieldCurrentWorkspace;
      case 'workspaceId':
        return l10n.adminConsoleFieldWorkspaceId;
      case 'owner':
        return l10n.adminConsoleFieldOwner;
      case 'archivedAt':
        return l10n.adminConsoleFieldArchivedAt;
      case 'opsNote':
        return l10n.adminConsoleFieldOpsNote;
      case 'projectId':
        return l10n.adminConsoleFieldProjectId;
      case 'workspace':
        return l10n.adminConsoleFieldWorkspace;
      case 'projectArchivedAt':
        return l10n.adminConsoleFieldProjectArchivedAt;
      case 'aclMode':
        return l10n.adminConsoleFieldAclMode;
      case 'editorCount':
        return l10n.adminConsoleFieldEditorCount;
      case 'viewerCount':
        return l10n.adminConsoleFieldViewerCount;
      default:
        return key;
    }
  }

  String _fmt(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) {
      return raw;
    }
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$mm-$dd $hh:$min';
  }

  String _jobProjectScopeLabel(AdminJobSummaryV1 job) {
    final numeric = job.projectNumericId;
    final projectId = job.projectId?.trim() ?? '';
    if (numeric != null && projectId.isNotEmpty) {
      return '#$numeric · $projectId';
    }
    if (numeric != null) {
      return '#$numeric';
    }
    if (projectId.isNotEmpty) {
      return projectId;
    }
    return '-';
  }
}
