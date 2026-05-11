import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'controller.dart';

class NotificationsSection extends StatefulWidget {
  const NotificationsSection({
    super.key,
    required this.controller,
    required this.onOpenNotification,
  });

  final NotificationsController controller;
  final ValueChanged<NotificationRecordV1> onOpenNotification;

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  static const List<String> _complianceStages = <String>[
    'critical_unclaimed',
    'over_capacity',
    'stalled_claimed',
    'escalated_72h',
  ];

  final _searchController = TextEditingController();
  final _workspaceAuditTemplateFilterController = TextEditingController();
  final _workspaceAuditStartAtController = TextEditingController();
  final _workspaceAuditEndAtController = TextEditingController();
  final _clearedThrottleController = TextEditingController();
  final _clearedThrottleFocus = FocusNode();
  final Map<String, TextEditingController> _stageThrottleControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _stageThrottleFocusNodes = <String, FocusNode>{};
  String _typeFilter = 'all';
  bool _unreadOnly = false;
  bool _customTemplatesOnly = false;
  String _workspaceAuditActionFilter = '';
  String _exportHistoryFormat = '';
  final _exportHistoryExportedStartController = TextEditingController();
  final _exportHistoryExportedEndController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _clearedThrottleController.text =
        '${widget.controller.contentComplianceClearedThrottleMinutes}';
    for (final stage in _complianceStages) {
      _stageThrottleControllers[stage] = TextEditingController();
      _stageThrottleFocusNodes[stage] = FocusNode();
    }
    _syncStageThrottleControllersFromState();
    widget.controller.addListener(_handleControllerChanged);
    widget.controller.prime();
  }

  @override
  void didUpdateWidget(covariant NotificationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      widget.controller.prime();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _searchController.dispose();
    _workspaceAuditTemplateFilterController.dispose();
    _workspaceAuditStartAtController.dispose();
    _workspaceAuditEndAtController.dispose();
    _exportHistoryExportedStartController.dispose();
    _exportHistoryExportedEndController.dispose();
    _clearedThrottleController.dispose();
    _clearedThrottleFocus.dispose();
    for (final controller in _stageThrottleControllers.values) {
      controller.dispose();
    }
    for (final node in _stageThrottleFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!_clearedThrottleFocus.hasFocus) {
      final next =
          '${widget.controller.contentComplianceClearedThrottleMinutes}';
      if (_clearedThrottleController.text != next) {
        _clearedThrottleController.text = next;
      }
    }
    _syncStageThrottleControllersFromState();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncStageThrottleControllersFromState() {
    final stagePolicy =
        widget.controller.contentComplianceClearedStageThrottleMinutes;
    for (final stage in _complianceStages) {
      final controller = _stageThrottleControllers[stage];
      final focusNode = _stageThrottleFocusNodes[stage];
      if (controller == null || focusNode == null || focusNode.hasFocus) {
        continue;
      }
      final minutes = stagePolicy[stage];
      final nextText = minutes == null ? '' : '$minutes';
      if (controller.text != nextText) {
        controller.text = nextText;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final needle = _searchController.text.trim().toLowerCase();
    final filtered = widget.controller.items
        .where((item) {
          if (_unreadOnly && !item.isUnread) {
            return false;
          }
          if (_typeFilter != 'all' &&
              !_matchesTypeFilter(item.notificationType)) {
            return false;
          }
          if (needle.isEmpty) {
            return true;
          }
          final haystack = <String>[
            item.title,
            item.message,
            item.notificationType,
            item.filePath ?? '',
            item.jobId ?? '',
            item.workspaceId ?? '',
            item.projectId ?? '',
            item.payload.toString(),
          ].join(' ').toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
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
                    Text(
                      l10n.notificationsCenterTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.notificationsCenterSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    widget.controller.markingAllRead ||
                        widget.controller.unreadCount == 0
                    ? null
                    : widget.controller.markAllRead,
                icon: widget.controller.markingAllRead
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all_outlined),
                label: Text(l10n.notificationsMarkAllRead),
              ),
              const SizedBox(width: 4),
              RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.notificationsRiskyPrefsTooltip,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('合规 cleared 节流（分钟）', style: theme.textTheme.bodyMedium),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _clearedThrottleController,
                    focusNode: _clearedThrottleFocus,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '1-1440',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.controller.savingPreferences
                      ? null
                      : _saveClearedThrottlePolicy,
                  child: widget.controller.savingPreferences
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存策略'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.controller.savingPreferences
                      ? null
                      : _createTemplateFromCurrentPolicy,
                  icon: const Icon(Icons.add),
                  label: const Text('保存为模板'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      widget.controller.savingPreferences ||
                          !widget.controller.canManageWorkspaceSharedTemplates
                      ? null
                      : _createWorkspaceSharedTemplateFromCurrentPolicy,
                  icon: const Icon(Icons.group_work_outlined),
                  label: const Text('保存到工作区共享'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.controller.savingPreferences
                      ? null
                      : _exportTemplatesToClipboard,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('导出模板 JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.controller.savingPreferences
                      ? null
                      : _openImportTemplatesDialog,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('导入模板 JSON'),
                ),
                Text(
                  '同一 stage 在窗口内只发一次 cleared，降低抖动噪音。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                FilterChip(
                  selected: _customTemplatesOnly,
                  label: const Text('仅自定义模板'),
                  onSelected: (selected) {
                    setState(() {
                      _customTemplatesOnly = selected;
                    });
                  },
                ),
                ...widget.controller.complianceClearedTemplates
                    .where(
                      (template) =>
                          !_customTemplatesOnly || template.kind == 'custom',
                    )
                    .map(
                      (template) => Tooltip(
                        message: template.description,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ActionChip(
                              label: Text('模板：${template.label}'),
                              onPressed: widget.controller.savingPreferences
                                  ? null
                                  : () => _applyThrottleTemplate(template.id),
                            ),
                            IconButton(
                              tooltip: '上移',
                              onPressed: widget.controller.savingPreferences
                                  ? null
                                  : () =>
                                        _reorderTemplate(template.id, up: true),
                              icon: const Icon(Icons.arrow_upward, size: 18),
                            ),
                            IconButton(
                              tooltip: '下移',
                              onPressed: widget.controller.savingPreferences
                                  ? null
                                  : () => _reorderTemplate(
                                      template.id,
                                      up: false,
                                    ),
                              icon: const Icon(Icons.arrow_downward, size: 18),
                            ),
                            IconButton(
                              tooltip: '编辑模板',
                              onPressed:
                                  widget.controller.savingPreferences ||
                                      !template.canEdit
                                  ? null
                                  : () => _editTemplate(template),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: '删除模板',
                              onPressed:
                                  widget.controller.savingPreferences ||
                                      !template.canDelete
                                  ? null
                                  : () => _deleteTemplate(template),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (widget
                    .controller
                    .workspaceSharedComplianceTemplates
                    .isNotEmpty)
                  Text(
                    '工作区共享模板',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ...widget.controller.workspaceSharedComplianceTemplates.map(
                  (template) => Tooltip(
                    message: template.description,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ActionChip(
                          label: Text('共享：${template.label}'),
                          onPressed: widget.controller.savingPreferences
                              ? null
                              : () => _applyThrottleTemplate(template.id),
                        ),
                        IconButton(
                          tooltip: '编辑共享模板',
                          onPressed:
                              widget.controller.savingPreferences ||
                                  !widget
                                      .controller
                                      .canManageWorkspaceSharedTemplates
                              ? null
                              : () => _editWorkspaceSharedTemplate(template),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                        IconButton(
                          tooltip: '删除共享模板',
                          onPressed:
                              widget.controller.savingPreferences ||
                                  !widget
                                      .controller
                                      .canManageWorkspaceSharedTemplates
                              ? null
                              : () => _deleteWorkspaceSharedTemplate(template),
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                ..._complianceStages.map(
                  (stage) => SizedBox(
                    width: 190,
                    child: TextField(
                      controller: _stageThrottleControllers[stage],
                      focusNode: _stageThrottleFocusNodes[stage],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '$stage 覆盖值',
                        hintText: '留空=跟随全局',
                      ),
                    ),
                  ),
                ),
                Text(
                  _buildPreferencesAuditText(
                    widget.controller.preferencesAudit,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(
                  width: 860,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '共享模板审计',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _workspaceAuditTemplateFilterController,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: '模板 ID 过滤',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _workspaceAuditActionFilter,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: '动作过滤',
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('全部')),
                            DropdownMenuItem(
                              value: 'upsert',
                              child: Text('upsert'),
                            ),
                            DropdownMenuItem(
                              value: 'delete',
                              child: Text('delete'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _workspaceAuditActionFilter = value ?? '';
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _workspaceAuditStartAtController,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: '开始时间(ISO8601)',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _workspaceAuditEndAtController,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: '结束时间(ISO8601)',
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: widget.controller.loadingWorkspaceSharedAudit
                            ? null
                            : _reloadWorkspaceAuditWithFilters,
                        child: const Text('应用筛选'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.controller.loadingWorkspaceSharedAudit
                            ? null
                            : _exportWorkspaceAuditJsonToClipboard,
                        icon: const Icon(Icons.data_object),
                        label: const Text('下载审计 JSON'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.controller.loadingWorkspaceSharedAudit
                            ? null
                            : _exportWorkspaceAuditCsvToClipboard,
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('下载审计 CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.controller.loadingWorkspaceSharedAudit ||
                                widget.controller.enqueueingWorkspaceSharedAuditAsyncExport
                            ? null
                            : () => _enqueueWorkspaceSharedAuditExportAsync('json'),
                        icon: const Icon(Icons.hourglass_empty_outlined),
                        label: const Text('异步 JSON'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.controller.loadingWorkspaceSharedAudit ||
                                widget.controller.enqueueingWorkspaceSharedAuditAsyncExport
                            ? null
                            : () => _enqueueWorkspaceSharedAuditExportAsync('csv'),
                        icon: const Icon(Icons.hourglass_empty_outlined),
                        label: const Text('异步 CSV'),
                      ),
                      if ((widget.controller.workspaceSharedAsyncExportInfo ?? '')
                          .trim()
                          .isNotEmpty)
                        SizedBox(
                          width: 860,
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.info_outline,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                widget.controller.workspaceSharedAsyncExportInfo!,
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: IconButton(
                                tooltip: '关闭',
                                icon: const Icon(Icons.close),
                                onPressed: widget.controller
                                    .clearWorkspaceSharedAsyncExportInfo,
                              ),
                            ),
                          ),
                        ),
                      Text(
                        '导出历史',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          // Controlled by _exportHistoryFormat via setState.
                          // ignore: deprecated_member_use
                          value: _exportHistoryFormat,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: '导出格式筛选',
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('全部')),
                            DropdownMenuItem(
                              value: 'json',
                              child: Text('JSON'),
                            ),
                            DropdownMenuItem(value: 'csv', child: Text('CSV')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _exportHistoryFormat = value ?? '';
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _exportHistoryExportedStartController,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: '导出时间起(ISO)',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _exportHistoryExportedEndController,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: '导出时间止(ISO)',
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: widget.controller.loadingExportHistory
                            ? null
                            : _applyExportHistoryFilters,
                        child: widget.controller.loadingExportHistory
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('筛选导出历史'),
                      ),
                      ...widget.controller.workspaceSharedAuditExports.map(
                        (item) => SizedBox(
                          width: 800,
                          child: Tooltip(
                            message: _formatWorkspaceAuditExportItem(item),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatWorkspaceAuditExportItem(item),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '复用该次筛选到上方',
                                  onPressed:
                                      widget
                                          .controller
                                          .loadingWorkspaceSharedAudit
                                      ? null
                                      : () => _reuseExportRecordFilters(item),
                                  icon: const Icon(
                                    Icons.filter_alt_outlined,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: _exportRecordDownloadTooltip(item),
                                  onPressed:
                                      widget.controller.loadingExportHistory
                                      ? null
                                      : () => _redownloadFromExportRecord(item),
                                  icon: const Icon(
                                    Icons.download_outlined,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.controller.workspaceSharedExportHistoryHasMore)
                        TextButton.icon(
                          onPressed: widget.controller.loadingExportHistory
                              ? null
                              : widget.controller.loadMoreExportHistory,
                          icon: widget.controller.loadingExportHistory
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more, size: 18),
                          label: const Text('更多导出记录'),
                        ),
                      ...widget.controller.workspaceSharedComplianceAudit
                          .take(6)
                          .map(
                            (item) => Text(
                              _formatWorkspaceAuditItem(item),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      if (widget.controller.workspaceSharedAuditHasMore)
                        TextButton.icon(
                          onPressed:
                              widget.controller.loadingWorkspaceSharedAudit
                              ? null
                              : widget
                                    .controller
                                    .loadMoreWorkspaceSharedComplianceAudit,
                          icon: widget.controller.loadingWorkspaceSharedAudit
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more, size: 18),
                          label: const Text('加载更多审计'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                selected: _unreadOnly,
                onSelected: (selected) {
                  setState(() {
                    _unreadOnly = selected;
                  });
                },
                label: Text(
                  l10n.notificationsFilterUnread(widget.controller.unreadCount),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  decoration: InputDecoration(
                    labelText: l10n.notificationsTypeFilterLabel,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(l10n.notificationsTypeAll),
                    ),
                    DropdownMenuItem(
                      value: 'job',
                      child: Text(l10n.notificationsTypeJob),
                    ),
                    DropdownMenuItem(
                      value: 'workspace',
                      child: Text(l10n.notificationsTypeWorkspace),
                    ),
                    DropdownMenuItem(
                      value: 'skill',
                      child: Text(l10n.notificationsTypeSkill),
                    ),
                    DropdownMenuItem(
                      value: 'compliance',
                      child: Text(l10n.notificationsTypeCompliance),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _typeFilter = value;
                    });
                  },
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.notificationsSearchLabel,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.controller.loading
                    ? null
                    : widget.controller.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.notificationsRefresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.controller.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.notificationsEmptyFiltered,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...filtered.map(
              (item) => _buildNotificationTile(context, l10n, item),
            ),
          if (widget.controller.hasMore) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.controller.loadingMore
                    ? null
                    : widget.controller.loadMore,
                icon: widget.controller.loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(l10n.notificationsLoadMore),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppLocalizations l10n,
    NotificationRecordV1 item,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: item.isUnread
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
        color: item.isUnread
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.18)
            : null,
      ),
      child: ListTile(
        leading: Icon(_iconForType(item.notificationType)),
        title: Row(
          children: [
            Expanded(child: Text(item.title)),
            if (item.isUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.notificationsUnreadBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.message),
              const SizedBox(height: 6),
              Text(
                '${_notificationTypeLabel(l10n, item.notificationType)} · ${_formatDateTime(item.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (item.isUnread)
              TextButton(
                onPressed: () => widget.controller.markRead(item),
                child: Text(l10n.notificationsMarkRead),
              ),
            FilledButton.tonal(
              onPressed: () {
                if (item.isUnread) {
                  widget.controller.markRead(item);
                }
                widget.onOpenNotification(item);
              },
              child: Text(l10n.notificationsOpen),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesTypeFilter(String notificationType) {
    switch (_typeFilter) {
      case 'job':
        return notificationType.startsWith('job_');
      case 'workspace':
        return notificationType.startsWith('workspace_');
      case 'skill':
        return notificationType == 'skill_change';
      case 'compliance':
        return notificationType == 'content_compliance_alert' ||
            notificationType == 'content_compliance_alert_cleared';
      default:
        return true;
    }
  }

  IconData _iconForType(String notificationType) {
    if (notificationType.startsWith('job_')) {
      return Icons.task_alt_outlined;
    }
    if (notificationType.startsWith('workspace_')) {
      return Icons.groups_outlined;
    }
    if (notificationType == 'skill_change') {
      return Icons.auto_awesome_outlined;
    }
    if (notificationType == 'content_compliance_alert') {
      return Icons.gpp_maybe_outlined;
    }
    if (notificationType == 'content_compliance_alert_cleared') {
      return Icons.task_alt_outlined;
    }
    return Icons.notifications_none_outlined;
  }

  String _notificationTypeLabel(
    AppLocalizations l10n,
    String notificationType,
  ) {
    switch (notificationType) {
      case 'job_succeeded':
        return l10n.notificationsRecordJobSucceeded;
      case 'job_failed':
        return l10n.notificationsRecordJobFailed;
      case 'job_cancelled':
        return l10n.notificationsRecordJobCancelled;
      case 'workspace_invite_created':
        return l10n.notificationsRecordWorkspaceInviteCreated;
      case 'workspace_invite_resent':
        return l10n.notificationsRecordWorkspaceInviteResent;
      case 'workspace_invite_revoked':
        return l10n.notificationsRecordWorkspaceInviteRevoked;
      case 'workspace_invite_accepted':
        return l10n.notificationsRecordWorkspaceInviteAccepted;
      case 'skill_change':
        return l10n.notificationsRecordSkillChange;
      case 'content_compliance_alert':
        return l10n.notificationsRecordContentComplianceAlert;
      case 'content_compliance_alert_cleared':
        return l10n.notificationsRecordContentComplianceCleared;
      default:
        return notificationType;
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  void _saveClearedThrottlePolicy() {
    final globalRaw = _clearedThrottleController.text.trim();
    final globalMinutes = int.tryParse(globalRaw);
    if (globalMinutes == null || globalMinutes < 1 || globalMinutes > 1440) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入 1-1440 的整数分钟值')));
      return;
    }
    final stageMinutes = <String, int>{};
    for (final stage in _complianceStages) {
      final raw = _stageThrottleControllers[stage]?.text.trim() ?? '';
      if (raw.isEmpty) {
        continue;
      }
      final value = int.tryParse(raw);
      if (value == null || value < 1 || value > 1440) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$stage 请输入 1-1440 的整数分钟值，或留空')));
        return;
      }
      stageMinutes[stage] = value;
    }
    widget.controller.saveContentComplianceClearedThrottlePolicy(
      globalMinutes: globalMinutes,
      stageMinutes: stageMinutes,
    );
  }

  Future<void> _applyThrottleTemplate(String templateId) async {
    await widget.controller.applyComplianceClearedThrottleTemplate(templateId);
  }

  Future<void> _createTemplateFromCurrentPolicy() async {
    final idController = TextEditingController();
    final labelController = TextEditingController();
    final descriptionController = TextEditingController();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存 cleared 模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: '模板 ID（英文）'),
            ),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: '模板名称'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '模板说明'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (shouldSave != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    final id = idController.text.trim().toLowerCase();
    final label = labelController.text.trim();
    final description = descriptionController.text.trim();
    if (id.isEmpty || label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模板 ID 和名称不能为空')));
      return;
    }
    final stageMinutes = <String, int>{};
    for (final stage in _complianceStages) {
      final raw = _stageThrottleControllers[stage]?.text.trim() ?? '';
      final value = int.tryParse(raw);
      if (value != null && value >= 1 && value <= 1440) {
        stageMinutes[stage] = value;
      }
    }
    final global = int.tryParse(_clearedThrottleController.text.trim()) ?? 30;
    await widget.controller.upsertComplianceClearedTemplate(
      ContentComplianceClearedTemplateItemV1(
        id: id,
        label: label,
        description: description,
        policy: ContentComplianceClearedTemplatePolicyV1(
          globalMinutes: global.clamp(1, 1440),
          stageMinutes: stageMinutes,
        ),
        kind: 'custom',
        canEdit: true,
        canDelete: true,
      ),
    );
  }

  Future<void> _createWorkspaceSharedTemplateFromCurrentPolicy() async {
    final idController = TextEditingController();
    final labelController = TextEditingController();
    final descriptionController = TextEditingController();
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存工作区共享模板'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: '模板 ID（英文）'),
            ),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: '模板名称'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '模板说明'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (shouldSave != true || !mounted) {
      return;
    }
    final id = idController.text.trim().toLowerCase();
    final label = labelController.text.trim();
    final description = descriptionController.text.trim();
    if (id.isEmpty || label.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('模板 ID 和名称不能为空')));
      return;
    }
    final stageMinutes = <String, int>{};
    for (final stage in _complianceStages) {
      final raw = _stageThrottleControllers[stage]?.text.trim() ?? '';
      final value = int.tryParse(raw);
      if (value != null && value >= 1 && value <= 1440) {
        stageMinutes[stage] = value;
      }
    }
    final global = int.tryParse(_clearedThrottleController.text.trim()) ?? 30;
    await widget.controller.upsertWorkspaceSharedComplianceClearedTemplate(
      ContentComplianceClearedTemplateItemV1(
        id: id,
        label: label,
        description: description,
        policy: ContentComplianceClearedTemplatePolicyV1(
          globalMinutes: global.clamp(1, 1440),
          stageMinutes: stageMinutes,
        ),
        kind: 'workspace_shared',
        canEdit: true,
        canDelete: true,
      ),
    );
  }

  Future<void> _editTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final labelController = TextEditingController(text: template.label);
    final descriptionController = TextEditingController(
      text: template.description,
    );
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑模板：${template.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: '模板名称'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '模板说明'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (shouldSave != true) {
      return;
    }
    await widget.controller.upsertComplianceClearedTemplate(
      ContentComplianceClearedTemplateItemV1(
        id: template.id,
        label: labelController.text.trim().isEmpty
            ? template.label
            : labelController.text.trim(),
        description: descriptionController.text.trim(),
        policy: template.policy,
        kind: template.kind,
        canEdit: template.canEdit,
        canDelete: template.canDelete,
      ),
    );
  }

  Future<void> _deleteTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除模板：${template.label}'),
        content: const Text('删除后不可恢复，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }
    await widget.controller.deleteComplianceClearedTemplate(template.id);
  }

  Future<void> _deleteWorkspaceSharedTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除共享模板：${template.label}'),
        content: const Text('删除后会影响当前工作区所有成员，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }
    await widget.controller.deleteWorkspaceSharedComplianceClearedTemplate(
      template.id,
    );
  }

  Future<void> _editWorkspaceSharedTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final labelController = TextEditingController(text: template.label);
    final descriptionController = TextEditingController(
      text: template.description,
    );
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑共享模板：${template.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: '模板名称'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '模板说明'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (shouldSave != true) {
      return;
    }
    await widget.controller.upsertWorkspaceSharedComplianceClearedTemplate(
      ContentComplianceClearedTemplateItemV1(
        id: template.id,
        label: labelController.text.trim().isEmpty
            ? template.label
            : labelController.text.trim(),
        description: descriptionController.text.trim(),
        policy: template.policy,
        kind: template.kind,
        canEdit: template.canEdit,
        canDelete: template.canDelete,
      ),
    );
  }

  Future<void> _reloadWorkspaceAuditWithFilters() async {
    final startAt = DateTime.tryParse(
      _workspaceAuditStartAtController.text.trim(),
    );
    final endAt = DateTime.tryParse(_workspaceAuditEndAtController.text.trim());
    await widget.controller.reloadWorkspaceSharedComplianceAudit(
      templateId: _workspaceAuditTemplateFilterController.text.trim(),
      action: _workspaceAuditActionFilter.trim(),
      startAt: startAt,
      endAt: endAt,
    );
  }

  Future<void> _applyExportHistoryFilters() async {
    await widget.controller.applyExportHistoryFiltersAndReload(
      formatFilter: _exportHistoryFormat,
      exportedStart: DateTime.tryParse(
        _exportHistoryExportedStartController.text.trim(),
      ),
      exportedEnd: DateTime.tryParse(
        _exportHistoryExportedEndController.text.trim(),
      ),
    );
  }

  Future<void> _reuseExportRecordFilters(
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) async {
    _workspaceAuditTemplateFilterController.text = item.templateId ?? '';
    final act = (item.action ?? '').trim();
    setState(() {
      _workspaceAuditActionFilter = act == 'upsert' || act == 'delete'
          ? act
          : '';
    });
    _workspaceAuditStartAtController.text = (item.startAt ?? '').trim();
    _workspaceAuditEndAtController.text = (item.endAt ?? '').trim();
    await widget.controller.applyExportRecordToSharedAuditFilters(item);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复用该次导出的筛选并刷新审计列表')));
  }

  Future<void> _redownloadFromExportRecord(
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) async {
    final path = await widget.controller
        .downloadWorkspaceSharedComplianceAuditWithExportRecord(item);
    if (!mounted || path == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已按历史条件下载：$path')));
  }

  Future<void> _enqueueWorkspaceSharedAuditExportAsync(String format) async {
    final job = await widget.controller
        .enqueueWorkspaceSharedComplianceAuditExportAsync(format: format);
    if (!mounted) {
      return;
    }
    if (job == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '后台导出已排队（任务 #${job.numericTaskId}）。导出历史会在任务完成后自动刷新。',
        ),
      ),
    );
    widget.controller.scheduleWorkspaceSharedAuditExportHistoryPoll(job.id);
  }

  Future<void> _exportWorkspaceAuditJsonToClipboard() async {
    final savedPath = await widget.controller
        .downloadWorkspaceSharedComplianceAuditJson();
    if (!mounted || savedPath == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('共享审计 JSON 已下载：$savedPath')));
  }

  Future<void> _exportWorkspaceAuditCsvToClipboard() async {
    final savedPath = await widget.controller
        .downloadWorkspaceSharedComplianceAuditCsv();
    if (!mounted || savedPath == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('共享审计 CSV 已下载：$savedPath')));
  }

  Future<void> _reorderTemplate(String id, {required bool up}) async {
    final ids = widget.controller.complianceClearedTemplates
        .map((template) => template.id)
        .toList(growable: true);
    final index = ids.indexOf(id);
    if (index < 0) {
      return;
    }
    final target = up ? index - 1 : index + 1;
    if (target < 0 || target >= ids.length) {
      return;
    }
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    await widget.controller.reorderComplianceClearedTemplates(ids);
  }

  Future<void> _exportTemplatesToClipboard() async {
    final json = await widget.controller.exportComplianceClearedTemplatesJson();
    if (!mounted || json == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('模板 JSON 已复制到剪贴板')));
  }

  Future<void> _openImportTemplatesDialog() async {
    final jsonController = TextEditingController();
    String mode = 'replace';
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('导入模板 JSON'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(
                    labelText: '导入模式',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'replace',
                      child: Text('replace（覆盖）'),
                    ),
                    DropdownMenuItem(value: 'merge', child: Text('merge（合并）')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      mode = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: jsonController,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: '粘贴模板 JSON',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('导入'),
            ),
          ],
        ),
      ),
    );
    if (shouldImport != true || !mounted) {
      return;
    }
    final count = await widget.controller.importComplianceClearedTemplatesJson(
      jsonController.text.trim(),
      mode: mode,
    );
    if (!mounted || count == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('导入完成：$count 条模板')));
  }

  String _buildPreferencesAuditText(NotificationPreferencesAuditMetaV1 audit) {
    final updatedAt = audit.updatedAt;
    final timePart = updatedAt == null ? '未知时间' : _formatDateTime(updatedAt);
    return '策略最近更新：$timePart · ${audit.updatedBy} · ${audit.source}';
  }

  String _formatWorkspaceAuditItem(
    ContentComplianceClearedTemplateAuditItemV1 item,
  ) {
    final at = item.at == null ? '未知时间' : _formatDateTime(item.at!);
    final note = (item.note ?? '').trim();
    final actionLabel = switch (item.action.trim().toLowerCase()) {
      'upsert' => '新增/更新',
      'delete' => '删除',
      _ => item.action,
    };
    if (note.isEmpty) {
      return '$at $actionLabel ${item.templateId}';
    }
    return '$at $actionLabel ${item.templateId} · $note';
  }

  String _exportRecordDownloadTooltip(
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) {
    final d = (item.exportDelivery ?? '').trim().toLowerCase();
    if (d == 'async' && (item.jobId ?? '').trim().isNotEmpty) {
      return '下载该次后台导出落盘的文件';
    }
    return '按相同条件再次下载（同步生成）';
  }

  String _formatWorkspaceAuditExportItem(
    WorkspaceSharedComplianceAuditExportRecordV1 item,
  ) {
    final when = item.exportedAt == null
        ? '未知时间'
        : _formatDateTime(item.exportedAt!);
    final format = item.format.toUpperCase();
    final action = (item.action ?? '').trim().isEmpty ? '全部动作' : item.action!;
    final template = (item.templateId ?? '').trim().isEmpty
        ? '全部模板'
        : item.templateId!;
    return '导出记录：$when · $format · $template · $action · ${item.fileName}'
        '${_exportDeliveryLabel(item)}';
  }

  String _exportDeliveryLabel(WorkspaceSharedComplianceAuditExportRecordV1 item) {
    final d = (item.exportDelivery ?? '').trim().toLowerCase();
    if (d == 'async') {
      final j = (item.jobId ?? '').trim();
      if (j.isNotEmpty) {
        return ' · 异步(job:$j)';
      }
      return ' · 异步';
    }
    if (d == 'sync') {
      return ' · 同步';
    }
    return '';
  }
}
