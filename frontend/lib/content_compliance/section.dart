import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';

class ContentComplianceSection extends StatefulWidget {
  const ContentComplianceSection({
    super.key,
    required this.controller,
    this.onOpenTarget,
    this.onOpenOpsTarget,
  });

  final ContentComplianceController controller;
  final Future<void> Function(ContentComplianceReportItemV1 item)? onOpenTarget;
  final Future<void> Function(ContentComplianceReportItemV1 item)?
  onOpenOpsTarget;

  @override
  State<ContentComplianceSection> createState() =>
      _ContentComplianceSectionState();
}

class _ContentComplianceSectionState extends State<ContentComplianceSection> {
  final _targetIdController = TextEditingController();
  final _detailController = TextEditingController();
  final _resolutionNoteController = TextEditingController();
  String _targetType = 'project';
  String _category = 'other';
  String _severity = 'medium';
  String _disposition = 'none';
  String _queueStatus = 'all';
  String _queueCategory = 'all';
  String _queueTargetType = 'all';
  String? _queueWorkspaceId;
  String? _queueWorkspaceName;
  String? _queueClaimedByLabel;
  String? _queueSlaBucket;
  bool _queueClaimedOnly = false;
  final Set<String> _selectedReportIds = <String>{};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _syncFilterStateFromController();
    if (widget.controller.queueEnabled) {
      widget.controller.loadQueue();
    }
  }

  @override
  void didUpdateWidget(covariant ContentComplianceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _syncFilterStateFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _targetIdController.dispose();
    _detailController.dispose();
    _resolutionNoteController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      _syncFilterStateFromController();
      setState(() {});
    }
  }

  void _syncFilterStateFromController() {
    _queueStatus = widget.controller.queueStatusFilter ?? 'all';
    _queueCategory = widget.controller.queueCategoryFilter ?? 'all';
    _queueTargetType = widget.controller.queueTargetTypeFilter ?? 'all';
    _queueWorkspaceId = widget.controller.queueWorkspaceIdFilter;
    _queueWorkspaceName = widget.controller.queueWorkspaceNameFilter;
    _queueClaimedByLabel = widget.controller.queueClaimedByLabelFilter;
    _queueSlaBucket = widget.controller.queueSlaBucketFilter;
    _queueClaimedOnly = widget.controller.queueClaimedOnly;
    final activeIds =
        widget.controller.queue?.items.map((item) => item.id).toSet() ??
        const <String>{};
    _selectedReportIds.removeWhere((id) => !activeIds.contains(id));
  }

  String _openTargetLabel(ContentComplianceReportItemV1 item) {
    switch (item.targetType) {
      case 'project':
        return '打开项目';
      case 'script':
        return '打开剧本项目';
      case 'storyboard':
        return '打开分镜项目';
      case 'asset':
        return '打开资产项目';
      case 'novel':
        return '打开小说项目';
      case 'user':
        return '查看用户上下文';
      default:
        return '打开上下文';
    }
  }

  List<String> _buildAuditLines(ContentComplianceReportItemV1 item) {
    final lines = <String>['created ${item.createdAt}'];
    if ((item.claimedByLabel ?? '').isNotEmpty ||
        (item.claimedAt ?? '').isNotEmpty) {
      lines.add(
        'claimed ${item.claimedByLabel ?? 'internal_ops'}'
        '${(item.claimedAt ?? '').isNotEmpty ? ' @ ${item.claimedAt}' : ''}',
      );
    }
    if ((item.resolutionLabel ?? '').isNotEmpty ||
        (item.resolvedAt ?? '').isNotEmpty) {
      lines.add(
        '${item.status} ${item.resolutionLabel ?? 'internal_ops'}'
        '${(item.resolvedAt ?? '').isNotEmpty ? ' @ ${item.resolvedAt}' : ''}',
      );
    }
    return lines;
  }

  String _auditSummary(ContentComplianceAuditItemV1 item) {
    final parts = <String>[
      item.action,
      if ((item.fromStatus ?? '').isNotEmpty ||
          (item.toStatus ?? '').isNotEmpty)
        '${item.fromStatus ?? '-'} -> ${item.toStatus ?? '-'}',
      item.actorLabel,
      if ((item.disposition ?? '').isNotEmpty)
        'disposition=${item.disposition}',
    ];
    return parts.join(' · ');
  }

  String _auditDetails(ContentComplianceAuditItemV1 item) {
    if (item.details.isEmpty) {
      return '{}';
    }
    return item.details.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }

  String _workspaceSummaryLabel(ContentComplianceWorkspaceSummaryV1 item) {
    final name = (item.workspaceName ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return 'Personal / direct user scope';
  }

  Future<void> _applyWorkspaceFilter(
    ContentComplianceWorkspaceSummaryV1 item,
  ) async {
    setState(() {
      _queueWorkspaceId = item.workspaceId;
      _queueWorkspaceName = item.workspaceName;
    });
    await widget.controller.applyQueueFilters(
      status: _queueStatus,
      category: _queueCategory,
      targetType: _queueTargetType,
      workspaceId: item.workspaceId,
      workspaceName: item.workspaceName,
      claimedByLabel: _queueClaimedByLabel,
      slaBucket: _queueSlaBucket,
      claimedOnly: _queueClaimedOnly,
    );
  }

  String _ownerSummaryLabel(ContentComplianceOwnerSummaryV1 item) {
    return item.ownerLabel == 'unclaimed' ? '未认领' : item.ownerLabel;
  }

  Future<void> _applyOwnerFilter(ContentComplianceOwnerSummaryV1 item) async {
    setState(() {
      _queueClaimedByLabel = item.ownerLabel;
    });
    await widget.controller.applyQueueFilters(
      status: _queueStatus,
      category: _queueCategory,
      targetType: _queueTargetType,
      workspaceId: _queueWorkspaceId,
      workspaceName: _queueWorkspaceName,
      claimedByLabel: item.ownerLabel,
      slaBucket: _queueSlaBucket,
      claimedOnly: _queueClaimedOnly,
    );
  }

  Future<void> _applySlaBucketFilter(String? bucket) async {
    setState(() {
      _queueSlaBucket = bucket;
    });
    await widget.controller.applyQueueFilters(
      status: _queueStatus,
      category: _queueCategory,
      targetType: _queueTargetType,
      workspaceId: _queueWorkspaceId,
      workspaceName: _queueWorkspaceName,
      claimedByLabel: _queueClaimedByLabel,
      slaBucket: bucket,
      claimedOnly: _queueClaimedOnly,
    );
  }

  Future<void> _runBulkAction(String action) async {
    if (_selectedReportIds.isEmpty) {
      return;
    }
    final verb = switch (action) {
      'claim' => '批量 claim',
      'resolve' => '批量 resolve',
      'dismiss' => '批量 dismiss',
      _ => '批量操作',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(verb),
        content: Text(
          '确定对 ${_selectedReportIds.length} 条举报执行$verb吗？'
          '${_resolutionNoteController.text.trim().isNotEmpty ? '\n\n会复用当前 resolution note。' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final response = await widget.controller.batchMutateReports(
      reportIds: _selectedReportIds.toList(growable: false),
      action: action,
      disposition: _disposition,
      resolutionNote: _resolutionNoteController.text,
    );
    if (!mounted || response == null) {
      return;
    }
    setState(() {
      _selectedReportIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$verb 完成：成功 ${response.succeededCount}，失败 ${response.failedCount}',
        ),
      ),
    );
  }

  Future<void> _showAuditDialog(ContentComplianceReportItemV1 item) async {
    final rows = await widget.controller.fetchReportAudit(item.id);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text('举报审计 · ${item.id}'),
          content: SizedBox(
            width: 640,
            child: rows.isEmpty
                ? const Text('当前没有可展示的审计记录。')
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: rows
                          .map(
                            (audit) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _auditSummary(audit),
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      audit.createdAt,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      _auditDetails(audit),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = widget.controller.queue;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('内容与合规', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '同一入口支持用户提交内容举报，以及 internal ops 的 claim / resolve 审核队列。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text('提交举报', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownMenu<String>(
                  initialSelection: _targetType,
                  label: const Text('targetType'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'project', label: 'project'),
                    DropdownMenuEntry(value: 'script', label: 'script'),
                    DropdownMenuEntry(value: 'storyboard', label: 'storyboard'),
                    DropdownMenuEntry(value: 'asset', label: 'asset'),
                    DropdownMenuEntry(value: 'novel', label: 'novel'),
                    DropdownMenuEntry(value: 'user', label: 'user'),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _targetType = value;
                    });
                  },
                ),
                DropdownMenu<String>(
                  initialSelection: _category,
                  label: const Text('category'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'copyright', label: 'copyright'),
                    DropdownMenuEntry(value: 'safety', label: 'safety'),
                    DropdownMenuEntry(value: 'harassment', label: 'harassment'),
                    DropdownMenuEntry(value: 'adult', label: 'adult'),
                    DropdownMenuEntry(value: 'violence', label: 'violence'),
                    DropdownMenuEntry(value: 'spam', label: 'spam'),
                    DropdownMenuEntry(value: 'other', label: 'other'),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _category = value;
                    });
                  },
                ),
                DropdownMenu<String>(
                  initialSelection: _severity,
                  label: const Text('severity'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'low', label: 'low'),
                    DropdownMenuEntry(value: 'medium', label: 'medium'),
                    DropdownMenuEntry(value: 'high', label: 'high'),
                    DropdownMenuEntry(value: 'critical', label: 'critical'),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _severity = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetIdController,
              decoration: const InputDecoration(
                labelText: 'target UUID',
                hintText: '输入被举报对象 UUID',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '补充说明',
                hintText: '可填写上下文、时间线或风险描述',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: widget.controller.submittingReport
                  ? null
                  : () => widget.controller.submitReport(
                      targetType: _targetType,
                      targetId: _targetIdController.text,
                      category: _category,
                      severity: _severity,
                      detail: _detailController.text,
                    ),
              icon: widget.controller.submittingReport
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.report_outlined),
              label: Text(widget.controller.submittingReport ? '提交中…' : '提交举报'),
            ),
            if (widget.controller.queueEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('审核队列', style: theme.textTheme.titleSmall),
                  ),
                  TextButton.icon(
                    onPressed:
                        widget.controller.loadingQueue ||
                            (!_queueClaimedOnly &&
                                _queueStatus == 'all' &&
                                _queueCategory == 'all' &&
                                _queueTargetType == 'all' &&
                                (_queueWorkspaceId ?? '').isEmpty &&
                                (_queueClaimedByLabel ?? '').isEmpty &&
                                (_queueSlaBucket ?? '').isEmpty)
                        ? null
                        : widget.controller.clearQueueFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('清空筛选'),
                  ),
                  TextButton.icon(
                    onPressed: widget.controller.loadingQueue
                        ? null
                        : widget.controller.loadQueue,
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新'),
                  ),
                ],
              ),
              if (queue != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DropdownMenu<String>(
                      initialSelection: _queueStatus,
                      label: const Text('status'),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'all', label: 'all'),
                        DropdownMenuEntry(value: 'pending', label: 'pending'),
                        DropdownMenuEntry(value: 'claimed', label: 'claimed'),
                        DropdownMenuEntry(value: 'resolved', label: 'resolved'),
                        DropdownMenuEntry(
                          value: 'dismissed',
                          label: 'dismissed',
                        ),
                      ],
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _queueStatus = value;
                        });
                        widget.controller.applyQueueFilters(
                          status: value,
                          category: _queueCategory,
                          targetType: _queueTargetType,
                          workspaceId: _queueWorkspaceId,
                          workspaceName: _queueWorkspaceName,
                          claimedByLabel: _queueClaimedByLabel,
                          slaBucket: _queueSlaBucket,
                          claimedOnly: _queueClaimedOnly,
                        );
                      },
                    ),
                    DropdownMenu<String>(
                      initialSelection: _queueCategory,
                      label: const Text('category'),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'all', label: 'all'),
                        DropdownMenuEntry(
                          value: 'copyright',
                          label: 'copyright',
                        ),
                        DropdownMenuEntry(value: 'safety', label: 'safety'),
                        DropdownMenuEntry(
                          value: 'harassment',
                          label: 'harassment',
                        ),
                        DropdownMenuEntry(value: 'adult', label: 'adult'),
                        DropdownMenuEntry(value: 'violence', label: 'violence'),
                        DropdownMenuEntry(value: 'spam', label: 'spam'),
                        DropdownMenuEntry(value: 'other', label: 'other'),
                      ],
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _queueCategory = value;
                        });
                        widget.controller.applyQueueFilters(
                          status: _queueStatus,
                          category: value,
                          targetType: _queueTargetType,
                          workspaceId: _queueWorkspaceId,
                          workspaceName: _queueWorkspaceName,
                          claimedByLabel: _queueClaimedByLabel,
                          slaBucket: _queueSlaBucket,
                          claimedOnly: _queueClaimedOnly,
                        );
                      },
                    ),
                    DropdownMenu<String>(
                      initialSelection: _queueTargetType,
                      label: const Text('targetType'),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'all', label: 'all'),
                        DropdownMenuEntry(value: 'project', label: 'project'),
                        DropdownMenuEntry(value: 'script', label: 'script'),
                        DropdownMenuEntry(
                          value: 'storyboard',
                          label: 'storyboard',
                        ),
                        DropdownMenuEntry(value: 'asset', label: 'asset'),
                        DropdownMenuEntry(value: 'novel', label: 'novel'),
                        DropdownMenuEntry(value: 'user', label: 'user'),
                      ],
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _queueTargetType = value;
                        });
                        widget.controller.applyQueueFilters(
                          status: _queueStatus,
                          category: _queueCategory,
                          targetType: value,
                          workspaceId: _queueWorkspaceId,
                          workspaceName: _queueWorkspaceName,
                          claimedByLabel: _queueClaimedByLabel,
                          slaBucket: _queueSlaBucket,
                          claimedOnly: _queueClaimedOnly,
                        );
                      },
                    ),
                    FilterChip(
                      label: const Text('仅已 claim'),
                      selected: _queueClaimedOnly,
                      onSelected: (selected) {
                        setState(() {
                          _queueClaimedOnly = selected;
                        });
                        widget.controller.applyQueueFilters(
                          status: _queueStatus,
                          category: _queueCategory,
                          targetType: _queueTargetType,
                          workspaceId: _queueWorkspaceId,
                          workspaceName: _queueWorkspaceName,
                          claimedByLabel: _queueClaimedByLabel,
                          slaBucket: _queueSlaBucket,
                          claimedOnly: selected,
                        );
                      },
                    ),
                    if ((_queueWorkspaceId ?? '').isNotEmpty ||
                        (_queueWorkspaceName ?? '').isNotEmpty)
                      InputChip(
                        label: Text(_queueWorkspaceName ?? _queueWorkspaceId!),
                        onDeleted: () {
                          setState(() {
                            _queueWorkspaceId = null;
                            _queueWorkspaceName = null;
                          });
                          widget.controller.applyQueueFilters(
                            status: _queueStatus,
                            category: _queueCategory,
                            targetType: _queueTargetType,
                            workspaceId: '',
                            workspaceName: '',
                            claimedByLabel: _queueClaimedByLabel,
                            slaBucket: _queueSlaBucket,
                            claimedOnly: _queueClaimedOnly,
                          );
                        },
                      ),
                    if ((_queueClaimedByLabel ?? '').isNotEmpty)
                      InputChip(
                        label: Text(
                          _queueClaimedByLabel == 'unclaimed'
                              ? 'owner: 未认领'
                              : 'owner: ${_queueClaimedByLabel!}',
                        ),
                        onDeleted: () {
                          setState(() {
                            _queueClaimedByLabel = null;
                          });
                          widget.controller.applyQueueFilters(
                            status: _queueStatus,
                            category: _queueCategory,
                            targetType: _queueTargetType,
                            workspaceId: _queueWorkspaceId,
                            workspaceName: _queueWorkspaceName,
                            claimedByLabel: '',
                            slaBucket: _queueSlaBucket,
                            claimedOnly: _queueClaimedOnly,
                          );
                        },
                      ),
                    if ((_queueSlaBucket ?? '').isNotEmpty)
                      InputChip(
                        label: Text('SLA: ${_queueSlaBucket!}'),
                        onDeleted: () {
                          setState(() {
                            _queueSlaBucket = null;
                          });
                          widget.controller.applyQueueFilters(
                            status: _queueStatus,
                            category: _queueCategory,
                            targetType: _queueTargetType,
                            workspaceId: _queueWorkspaceId,
                            workspaceName: _queueWorkspaceName,
                            claimedByLabel: _queueClaimedByLabel,
                            slaBucket: '',
                            claimedOnly: _queueClaimedOnly,
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('pending ${queue.summary.pending}')),
                    Chip(label: Text('claimed ${queue.summary.claimed}')),
                    Chip(label: Text('resolved ${queue.summary.resolved}')),
                    Chip(label: Text('dismissed ${queue.summary.dismissed}')),
                    Chip(label: Text('critical ${queue.summary.critical}')),
                    Chip(label: Text('high ${queue.summary.high}')),
                    FilterChip(
                      label: Text('open>24h ${queue.sla.openOver24h}'),
                      selected: _queueSlaBucket == 'open_over_24h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'open_over_24h'
                            ? null
                            : 'open_over_24h',
                      ),
                    ),
                    FilterChip(
                      label: Text('open>72h ${queue.sla.openOver72h}'),
                      selected: _queueSlaBucket == 'open_over_72h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'open_over_72h'
                            ? null
                            : 'open_over_72h',
                      ),
                    ),
                    FilterChip(
                      label: Text('claimed>24h ${queue.sla.claimedOver24h}'),
                      selected: _queueSlaBucket == 'claimed_over_24h',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'claimed_over_24h'
                            ? null
                            : 'claimed_over_24h',
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        'critical未claim ${queue.sla.unclaimedCritical}',
                      ),
                      selected: _queueSlaBucket == 'unclaimed_critical',
                      onSelected: (_) => _applySlaBucketFilter(
                        _queueSlaBucket == 'unclaimed_critical'
                            ? null
                            : 'unclaimed_critical',
                      ),
                    ),
                    Chip(
                      label: Text('oldest ${queue.sla.oldestOpenAgeHours}h'),
                    ),
                  ],
                ),
                if (queue.ownerSummaries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'reviewer / owner 负载',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: queue.ownerSummaries
                        .map(
                          (owner) => SizedBox(
                            width: 220,
                            child: OutlinedButton(
                              onPressed: widget.controller.loadingQueue
                                  ? null
                                  : () => _applyOwnerFilter(owner),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.all(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _ownerSummaryLabel(owner),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'pending ${owner.pendingCount} · claimed ${owner.claimedCount}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'critical ${owner.criticalOpenCount} · overdue ${owner.overdueCount} · oldest ${owner.oldestOpenAgeHours}h',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (queue.workspaceSummaries.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('workspace 热点', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: queue.workspaceSummaries
                        .map(
                          (workspace) => SizedBox(
                            width: 230,
                            child: OutlinedButton(
                              onPressed: widget.controller.loadingQueue
                                  ? null
                                  : () => _applyWorkspaceFilter(workspace),
                              style: OutlinedButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.all(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _workspaceSummaryLabel(workspace),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'open ${workspace.openCount} · pending ${workspace.pendingCount} · claimed ${workspace.claimedCount}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'critical ${workspace.criticalOpenCount} · high ${workspace.highOpenCount} · SLA ${workspace.slaBreachedCount} · oldest ${workspace.oldestOpenAgeHours}h',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 8),
                if (queue.items.isEmpty)
                  Text(
                    '当前没有待处理举报',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ...queue.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _selectedReportIds.contains(item.id),
                                  onChanged: widget.controller.mutatingQueue
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            if (selected == true) {
                                              _selectedReportIds.add(item.id);
                                            } else {
                                              _selectedReportIds.remove(
                                                item.id,
                                              );
                                            }
                                          });
                                        },
                                ),
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Chip(
                                        label: Text(
                                          '${item.targetType} · ${item.category}',
                                        ),
                                      ),
                                      Chip(label: Text(item.severity)),
                                      Chip(label: Text(item.status)),
                                      if ((item.projectName ?? '').isNotEmpty)
                                        Chip(label: Text(item.projectName!)),
                                      if ((item.workspaceName ?? '').isNotEmpty)
                                        Chip(label: Text(item.workspaceName!)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              'report ${item.id}\n'
                              'target ${item.targetId}\n'
                              'reporter ${item.reporterEmail ?? item.reporterUserId}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _buildAuditLines(item).join('\n'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if ((item.detail ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                item.detail!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if ((item.resolutionNote ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'resolution: ${item.resolutionNote!}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: item.targetId),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已复制 target UUID'),
                                      ),
                                    );
                                  },
                                  child: const Text('复制 target'),
                                ),
                                OutlinedButton(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: item.id),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已复制 report UUID'),
                                      ),
                                    );
                                  },
                                  child: const Text('复制 report'),
                                ),
                                if (widget.onOpenTarget != null)
                                  OutlinedButton(
                                    onPressed: () => widget.onOpenTarget!(item),
                                    child: Text(_openTargetLabel(item)),
                                  ),
                                if (widget.onOpenOpsTarget != null)
                                  OutlinedButton(
                                    onPressed: () =>
                                        widget.onOpenOpsTarget!(item),
                                    child: const Text('管理台上下文'),
                                  ),
                                OutlinedButton(
                                  onPressed:
                                      widget.controller.loadingAuditReportId ==
                                          item.id
                                      ? null
                                      : () => _showAuditDialog(item),
                                  child: Text(
                                    widget.controller.loadingAuditReportId ==
                                            item.id
                                        ? '加载审计中…'
                                        : '查看审计',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      widget.controller.mutatingQueue ||
                                          item.status != 'pending'
                                      ? null
                                      : () => widget.controller.claimReport(
                                          item.id,
                                        ),
                                  child: const Text('claim'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      widget.controller.mutatingQueue ||
                                          (item.status != 'pending' &&
                                              item.status != 'claimed')
                                      ? null
                                      : () => widget.controller.resolveReport(
                                          item.id,
                                          status: 'resolved',
                                          disposition: _disposition,
                                          resolutionNote:
                                              _resolutionNoteController.text,
                                        ),
                                  child: const Text('resolve'),
                                ),
                                OutlinedButton(
                                  onPressed:
                                      widget.controller.mutatingQueue ||
                                          (item.status != 'pending' &&
                                              item.status != 'claimed')
                                      ? null
                                      : () => widget.controller.resolveReport(
                                          item.id,
                                          status: 'dismissed',
                                          disposition: _disposition,
                                          resolutionNote:
                                              _resolutionNoteController.text,
                                        ),
                                  child: const Text('dismiss'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (queue.items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text('已选 ${_selectedReportIds.length}'),
                        selected: _selectedReportIds.isNotEmpty,
                        onSelected: (_) {},
                      ),
                      OutlinedButton(
                        onPressed: widget.controller.mutatingQueue
                            ? null
                            : () {
                                final selectable = queue.items
                                    .where(
                                      (item) =>
                                          item.status == 'pending' ||
                                          item.status == 'claimed',
                                    )
                                    .map((item) => item.id)
                                    .toSet();
                                setState(() {
                                  _selectedReportIds
                                    ..clear()
                                    ..addAll(selectable);
                                });
                              },
                        child: const Text('全选开放项'),
                      ),
                      OutlinedButton(
                        onPressed: _selectedReportIds.isEmpty
                            ? null
                            : () => setState(() {
                                _selectedReportIds.clear();
                              }),
                        child: const Text('清空选择'),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            widget.controller.mutatingQueue ||
                                _selectedReportIds.isEmpty
                            ? null
                            : () => _runBulkAction('claim'),
                        child: const Text('批量 claim'),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            widget.controller.mutatingQueue ||
                                _selectedReportIds.isEmpty
                            ? null
                            : () => _runBulkAction('resolve'),
                        child: const Text('批量 resolve'),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            widget.controller.mutatingQueue ||
                                _selectedReportIds.isEmpty
                            ? null
                            : () => _runBulkAction('dismiss'),
                        child: const Text('批量 dismiss'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                DropdownMenu<String>(
                  initialSelection: _disposition,
                  label: const Text('disposition'),
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'none', label: 'none'),
                    DropdownMenuEntry(
                      value: 'archive_project',
                      label: 'archive_project',
                    ),
                    DropdownMenuEntry(
                      value: 'suspend_user',
                      label: 'suspend_user',
                    ),
                  ],
                  onSelected: (value) {
                    if (value == null) return;
                    setState(() {
                      _disposition = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _resolutionNoteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'resolution note',
                    hintText: 'claim / resolve 时可复用这段说明',
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
