import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'controller.dart';

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
  String? _governanceDraftFingerprint;
  String? _workspaceGovernanceDraftFingerprint;
  String? _projectGovernanceDraftFingerprint;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.controller.searchResult;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('管理台', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '内部治理面。统一检索用户、workspace、project、job；支持用户治理与 workspace 上下文修复，以及 workspace / project 归档与内部备注。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 420,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: widget.controller.search,
                    decoration: const InputDecoration(
                      labelText: '搜索 email / workspace / project / job',
                      hintText:
                          '支持 UUID 前缀、project numeric_id、status / kind 关键词',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: widget.controller.searching
                      ? null
                      : () => widget.controller.search(_searchController.text),
                  icon: widget.controller.searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_outlined),
                  label: const Text('搜索'),
                ),
                if (widget.controller.selectedKind != null)
                  TextButton.icon(
                    onPressed: widget.controller.clearDetail,
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: const Text('清空详情'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (result != null) ...[
            _buildSearchGroup(
              context,
              title: '用户',
              emptyText: '没有匹配用户',
              children: result.users
                  .map((item) => _userHitTile(context, item))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            _buildSearchGroup(
              context,
              title: 'Workspace',
              emptyText: '没有匹配 workspace',
              children: result.workspaces
                  .map((item) => _workspaceHitTile(context, item))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            _buildSearchGroup(
              context,
              title: 'Project',
              emptyText: '没有匹配 project',
              children: result.projects
                  .map((item) => _projectHitTile(context, item))
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            _buildSearchGroup(
              context,
              title: 'Job',
              emptyText: '没有匹配 job',
              children: result.jobs
                  .map((item) => _jobTile(context, item))
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.controller.loadingDetail)
            const Center(child: CircularProgressIndicator())
          else if (widget.controller.userDetail != null)
            _buildUserDetail(context, widget.controller.userDetail!)
          else if (widget.controller.workspaceDetail != null)
            _buildWorkspaceDetail(context, widget.controller.workspaceDetail!)
          else if (widget.controller.projectDetail != null)
            _buildProjectDetail(context, widget.controller.projectDetail!),
        ],
      ),
    );
  }

  Widget _buildSearchGroup(
    BuildContext context, {
    required String title,
    required String emptyText,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(
              emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _userHitTile(BuildContext context, AdminUserSearchHitV1 item) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item.email ?? item.userId),
      subtitle: Text(
        'plan ${item.planTier ?? 'free'} · ${item.operationalStatus} · ws ${item.workspaceCount} · project ${item.projectCount} · active job ${item.activeJobCount}',
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
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item.name),
      subtitle: Text(
        '${item.workspaceType} · member ${item.memberCount} · project ${item.projectCount} · active job ${item.activeJobCount}${item.archivedAt == null ? '' : ' · archived'}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => widget.controller.loadWorkspace(item.workspaceId),
    );
  }

  Widget _projectHitTile(BuildContext context, AdminProjectSearchHitV1 item) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.name?.trim().isNotEmpty == true
            ? item.name!
            : '#${item.numericId}',
      ),
      subtitle: Text(
        '#${item.numericId} · ${item.workspaceName ?? 'no workspace'} · ${item.ownerEmail ?? item.ownerUserId}'
        '${item.archivedAt == null ? '' : ' · archived'}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => widget.controller.loadProject(item.projectId),
    );
  }

  Widget _jobTile(BuildContext context, AdminJobSummaryV1 item) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${item.kind} · ${item.status}'),
      subtitle: Text(
        '${item.ownerEmail ?? item.ownerUserId} · project ${item.projectNumericId ?? '-'} · ${_fmt(item.createdAt)}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildUserDetail(
    BuildContext context,
    AdminUserDetailResponseV1 detail,
  ) {
    return _detailCard(
      context,
      title: detail.email ?? detail.userId,
      chips: [
        'plan ${detail.planTier}',
        'workspace ${detail.workspaceCount}',
        'project ${detail.projectCount}',
        'active job ${detail.activeJobCount}',
        'api key ${detail.apiKeyCount}',
        'unread notif ${detail.unreadNotificationCount}',
      ],
      sections: [
        _kvWrap({
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
          title: '成员归属',
          items: detail.memberships
              .map(
                (item) =>
                    '${item.workspaceName} · ${item.workspaceType} · ${item.role}'
                    '${item.archivedAt == null ? '' : ' · archived'}',
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: '最近作业',
          items: detail.recentJobs
              .map(
                (job) =>
                    '${job.kind} · ${job.status} · project ${job.projectNumericId ?? '-'} · ${_fmt(job.createdAt)}',
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: '治理审计',
          items: detail.governanceAudit
              .map(
                (item) =>
                    '${_fmt(item.createdAt)} · ${item.actorLabel} · ${_auditSummary(item)}',
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('治理动作', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('正常'),
              selected: _operationalStatus == AdminOperationalStatusV1.active,
              onSelected: (_) {
                setState(() {
                  _operationalStatus = AdminOperationalStatusV1.active;
                  _opsReasonController.clear();
                });
              },
            ),
            ChoiceChip(
              label: const Text('暂停'),
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
        const SizedBox(height: 8),
        TextField(
          controller: _opsReasonController,
          enabled: _statusRequiresReason,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: '暂停原因',
            hintText: _statusRequiresReason
                ? '例如：滥用、退款争议、人工风控命中'
                : '用户为正常状态时不保存暂停原因',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _opsNoteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '内部备注',
            hintText: '写给运营 / 支持 / 风控同事看的上下文',
          ),
        ),
        const SizedBox(height: 12),
        Text('日配额覆写', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          detail.dailyJobQuotaOverride == null
              ? '当前未覆写，沿用套餐默认配额。'
              : '当前覆写值：${detail.dailyJobQuotaOverride}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('保留当前'),
              selected: _quotaAction == AdminQuotaOverrideActionV1.preserve,
              onSelected: (_) {
                setState(() {
                  _quotaAction = AdminQuotaOverrideActionV1.preserve;
                });
              },
            ),
            ChoiceChip(
              label: const Text('清除覆写'),
              selected: _quotaAction == AdminQuotaOverrideActionV1.clear,
              onSelected: (_) {
                setState(() {
                  _quotaAction = AdminQuotaOverrideActionV1.clear;
                });
              },
            ),
            ChoiceChip(
              label: const Text('设置配额'),
              selected: _quotaAction == AdminQuotaOverrideActionV1.set,
              onSelected: (_) {
                setState(() {
                  _quotaAction = AdminQuotaOverrideActionV1.set;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _dailyQuotaController,
            enabled: _quotaRequiresValue,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'dailyJobQuota',
              hintText: _quotaRequiresValue
                  ? (detail.dailyJobQuotaOverride?.toString() ?? '例如 500')
                  : '仅在“设置配额”时生效',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
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
          label: Text(widget.controller.savingGovernance ? '保存中…' : '保存治理设置'),
        ),
      ],
    );
  }

  Widget _buildWorkspaceContextPanel(
    BuildContext context,
    AdminUserDetailResponseV1 detail,
  ) {
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
        Text('Workspace 上下文修复', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '用于处理 current_workspace 指向失效、成员已变更后仍停在旧 workspace 的场景。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.controller.savingWorkspaceContext
                  ? null
                  : () => widget.controller.updateUserWorkspaceContext(
                      userId: detail.userId,
                      action: AdminUserWorkspaceContextActionV1.resetToPersonal,
                    ),
              icon: const Icon(Icons.home_outlined),
              label: Text(
                personalMembership.isEmpty ? '补建并切回 Personal' : '切回 Personal',
              ),
            ),
            ...switchTargets.map(
              (item) => OutlinedButton(
                onPressed: widget.controller.savingWorkspaceContext
                    ? null
                    : () => widget.controller.updateUserWorkspaceContext(
                        userId: detail.userId,
                        action:
                            AdminUserWorkspaceContextActionV1.setToWorkspace,
                        workspaceId: item.workspaceId,
                      ),
                child: Text('切到 ${item.workspaceName}'),
              ),
            ),
          ],
        ),
        if (widget.controller.savingWorkspaceContext) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('正在修复 workspace 上下文…', style: theme.textTheme.bodySmall),
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
    final theme = Theme.of(context);
    final isPersonal = detail.workspaceType == 'personal';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workspace 治理', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (isPersonal)
          Text(
            '个人 workspace 不可归档；可维护内部备注（metadata.internalOps）。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Text(
            '企业 workspace：可归档（软冻结）或解档；内部备注写入 metadata.internalOps。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        if (!isPersonal) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('不动归档状态'),
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
              ChoiceChip(
                label: const Text('归档'),
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
              ChoiceChip(
                label: const Text('解档'),
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
          const SizedBox(height: 8),
        ],
        Text('内部备注', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('不变'),
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
            ChoiceChip(
              label: const Text('清除'),
              selected:
                  _workspaceOpsNoteAction ==
                  AdminWorkspaceOpsNoteActionV1.clear,
              onSelected: (_) {
                setState(() {
                  _workspaceOpsNoteAction = AdminWorkspaceOpsNoteActionV1.clear;
                });
              },
            ),
            ChoiceChip(
              label: const Text('写入/更新'),
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
        const SizedBox(height: 8),
        TextField(
          controller: _workspaceOpsNoteController,
          enabled: _workspaceOpsNoteRequiresValue,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '内部备注正文',
            hintText: _workspaceOpsNoteRequiresValue
                ? '仅在选择「写入/更新」时提交'
                : '选择「写入/更新」后可编辑',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
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
          label: Text(widget.controller.savingGovernance ? '保存中…' : '保存治理'),
        ),
      ],
    );
  }

  Widget _buildWorkspaceMemberRemediationPanel(
    BuildContext context,
    AdminWorkspaceDetailResponseV1 detail,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('成员修复', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '支持 internal ops 直接补成员、改角色、移除成员；移除时会顺带回退 current workspace 并清理该 workspace 下的项目 ACL 残留。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _workspaceMemberUserIdController,
                decoration: const InputDecoration(
                  labelText: '成员 userId',
                  hintText: '输入要补成员或修角色的用户 UUID',
                ),
              ),
            ),
            ChoiceChip(
              label: const Text('member'),
              selected:
                  _workspaceMemberRole == AdminWorkspaceMemberRoleV1.member,
              onSelected: (_) {
                setState(() {
                  _workspaceMemberRole = AdminWorkspaceMemberRoleV1.member;
                });
              },
            ),
            ChoiceChip(
              label: const Text('admin'),
              selected:
                  _workspaceMemberRole == AdminWorkspaceMemberRoleV1.admin,
              onSelected: (_) {
                setState(() {
                  _workspaceMemberRole = AdminWorkspaceMemberRoleV1.admin;
                });
              },
            ),
            FilledButton.tonalIcon(
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
                    ? '处理中…'
                    : '补成员 / 改角色',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...detail.members.map((member) {
          final isOwner = member.role == 'owner';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${member.email ?? member.userId} · ${member.role}',
                  style: theme.textTheme.bodySmall,
                ),
                if (!isOwner) ...[
                  OutlinedButton(
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
                    child: const Text('设为 member'),
                  ),
                  OutlinedButton(
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
                    child: const Text('设为 admin'),
                  ),
                  OutlinedButton(
                    onPressed: widget.controller.savingWorkspaceMembership
                        ? null
                        : () => widget.controller
                              .updateWorkspaceMemberRemediation(
                                workspaceId: detail.workspaceId,
                                action: AdminWorkspaceMemberRemediationActionV1
                                    .remove,
                                userId: member.userId,
                              ),
                    child: const Text('移除'),
                  ),
                ] else
                  Text(
                    'owner 请走 owner transfer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWorkspaceDetail(
    BuildContext context,
    AdminWorkspaceDetailResponseV1 detail,
  ) {
    return _detailCard(
      context,
      title: detail.name,
      chips: [
        detail.workspaceType,
        'member ${detail.memberCount}',
        'project ${detail.projectCount}',
        'active job ${detail.activeJobCount}',
        if (detail.archivedAt != null) 'archived',
      ],
      sections: [
        _kvWrap({
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
        _buildWorkspaceMemberRemediationPanel(context, detail),
        _subList(
          context,
          title: '成员',
          items: detail.members
              .map(
                (item) =>
                    '${item.email ?? item.userId} · ${item.role} · joined ${_fmt(item.createdAt)}',
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: '最近项目',
          items: detail.recentProjects
              .map(
                (item) =>
                    '#${item.numericId} ${item.name ?? ''} · ${item.ownerEmail ?? item.ownerUserId}',
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: '最近作业',
          items: detail.recentJobs
              .map(
                (job) =>
                    '${job.kind} · ${job.status} · project ${job.projectNumericId ?? '-'} · ${_fmt(job.createdAt)}',
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: '治理审计',
          items: detail.governanceAudit
              .map(
                (item) =>
                    '${_fmt(item.createdAt)} · ${item.actorLabel} · ${_workspaceAuditSummary(item)}',
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  bool get _projectOpsNoteRequiresValue =>
      _projectOpsNoteAction == AdminWorkspaceOpsNoteActionV1.set;

  Widget _buildProjectGovernancePanel(
    BuildContext context,
    AdminProjectDetailResponseV1 detail,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Project 治理', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '归档后该项目从成员列表与汇总统计中隐藏，且所有需 project scope 的 API 返回 403；解档恢复。内部备注写入 metadata.internalOps。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('不动归档状态'),
              selected:
                  _projectLifecycle == AdminProjectLifecycleActionV1.preserve,
              onSelected: (_) {
                setState(() {
                  _projectLifecycle = AdminProjectLifecycleActionV1.preserve;
                });
              },
            ),
            ChoiceChip(
              label: const Text('归档'),
              selected:
                  _projectLifecycle == AdminProjectLifecycleActionV1.archive,
              onSelected: (_) {
                setState(() {
                  _projectLifecycle = AdminProjectLifecycleActionV1.archive;
                });
              },
            ),
            ChoiceChip(
              label: const Text('解档'),
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
        const SizedBox(height: 8),
        Text('内部备注', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('不变'),
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
            ChoiceChip(
              label: const Text('清除'),
              selected:
                  _projectOpsNoteAction == AdminWorkspaceOpsNoteActionV1.clear,
              onSelected: (_) {
                setState(() {
                  _projectOpsNoteAction = AdminWorkspaceOpsNoteActionV1.clear;
                });
              },
            ),
            ChoiceChip(
              label: const Text('写入/更新'),
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
        const SizedBox(height: 8),
        TextField(
          controller: _projectOpsNoteController,
          enabled: _projectOpsNoteRequiresValue,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '内部备注正文',
            hintText: _projectOpsNoteRequiresValue
                ? '仅在选择「写入/更新」时提交'
                : '选择「写入/更新」后可编辑',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
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
          label: Text(widget.controller.savingGovernance ? '保存中…' : '保存治理'),
        ),
      ],
    );
  }

  Widget _buildProjectDetail(
    BuildContext context,
    AdminProjectDetailResponseV1 detail,
  ) {
    return _detailCard(
      context,
      title: detail.name?.trim().isNotEmpty == true
          ? '${detail.name} (#${detail.numericId})'
          : 'Project #${detail.numericId}',
      chips: [
        'script ${detail.scriptCount}',
        'asset ${detail.assetCount}',
        'job ${detail.jobCount}',
        'active job ${detail.activeJobCount}',
        if (detail.archivedAt != null) 'archived',
      ],
      sections: [
        _kvWrap({
          'projectId': detail.projectId,
          'owner': detail.ownerEmail ?? detail.ownerUserId,
          'workspace': detail.workspace?.name ?? '-',
          'projectArchivedAt': detail.archivedAt == null
              ? '-'
              : _fmt(detail.archivedAt!),
          'opsNote': detail.opsNote == null || detail.opsNote!.trim().isEmpty
              ? '-'
              : detail.opsNote!,
          'createdAt': detail.createdAt == null ? '-' : _fmt(detail.createdAt!),
          'updatedAt': detail.updatedAt == null ? '-' : _fmt(detail.updatedAt!),
        }),
        _buildProjectGovernancePanel(context, detail),
        _subList(
          context,
          title: '最近作业',
          items: detail.recentJobs
              .map(
                (job) =>
                    '${job.kind} · ${job.status} · ${job.ownerEmail ?? job.ownerUserId} · ${_fmt(job.createdAt)}',
              )
              .toList(growable: false),
        ),
        _subList(
          context,
          title: '治理审计',
          items: detail.governanceAudit
              .map(
                (item) =>
                    '${_fmt(item.createdAt)} · ${item.actorLabel} · ${_projectAuditSummary(item)}',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map((item) => Chip(label: Text(item)))
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          ...sections
              .expand((widget) => [widget, const SizedBox(height: 12)])
              .toList()
            ..removeLast(),
        ],
      ),
    );
  }

  Widget _kvWrap(Map<String, String> rows) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: rows.entries
          .map((entry) => Chip(label: Text('${entry.key}: ${entry.value}')))
          .toList(growable: false),
    );
  }

  Widget _subList(
    BuildContext context, {
    required String title,
    required List<String> items,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(
            '暂无数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(item, style: theme.textTheme.bodySmall),
            ),
          ),
      ],
    );
  }

  String _auditSummary(AdminUserGovernanceAuditSummaryV1 item) {
    final nextStatus = item.nextState['operationalStatus'];
    final nextQuota = item.nextState['dailyJobQuotaOverride'];
    return 'status=$nextStatus · quota=${nextQuota ?? 'null'}';
  }

  String _workspaceAuditSummary(AdminWorkspaceGovernanceAuditSummaryV1 item) {
    final action = item.nextState['action'];
    if (action == 'upsert' || action == 'remove') {
      final targetUserId =
          item.nextState['targetUserId'] ?? item.previousState['targetUserId'];
      final targetRole =
          item.nextState['targetRole'] ?? item.previousState['targetRole'];
      final prunedProjectAclCount = item.nextState['prunedProjectAclCount'];
      final currentWorkspaceReset = item.nextState['currentWorkspaceReset'];
      return 'action=$action · user=${targetUserId ?? '-'} · role=${targetRole ?? '-'} · prunedAcl=${prunedProjectAclCount ?? 0} · reset=${currentWorkspaceReset ?? false}';
    }
    final nextArchived = item.nextState['archivedAt'];
    final nextNote = item.nextState['opsNote'];
    return 'archivedAt=$nextArchived · opsNote=${nextNote ?? 'null'}';
  }

  String _projectAuditSummary(AdminProjectGovernanceAuditSummaryV1 item) {
    final nextArchived = item.nextState['archivedAt'];
    final nextNote = item.nextState['opsNote'];
    return 'archivedAt=$nextArchived · opsNote=${nextNote ?? 'null'}';
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
}
