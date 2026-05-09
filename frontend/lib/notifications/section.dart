import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api/settings/notifications.dart';

/// Notifications section widget
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
  NotificationsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.queryController.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _controller.queryController.removeListener(_handleQueryChanged);
    super.dispose();
  }

  void _handleQueryChanged() {
    _controller.notifyQueryChanged();
  }

  Future<void> _refresh() => _controller.refresh();

  String _formatAuditTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  Future<void> _exportPreferences() async {
    final envelope = await _controller.exportPreferencesEnvelope();
    if (!mounted || envelope == null) {
      return;
    }
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(envelope.toJson());
    await Clipboard.setData(ClipboardData(text: pretty));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('通知策略 JSON 已复制到剪贴板')));
  }

  Future<void> _importPreferences() async {
    final pasted = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('导入通知策略 JSON'),
          content: SizedBox(
            width: 640,
            child: TextField(
              controller: ctrl,
              maxLines: 16,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"envelope":{"preferences":{...},"audit":{...}}}',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
    if (!mounted || pasted == null) {
      return;
    }
    try {
      final raw = jsonDecode(pasted) as Map<String, dynamic>;
      final envelopeJson = (raw['envelope'] as Map<String, dynamic>?) ?? raw;
      final envelope = NotificationPreferencesEnvelopeV1.fromJson(envelopeJson);
      await _controller.importPreferencesEnvelope(envelope);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知策略已导入并生效')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Future<void> _openNotification(NotificationRecordV1 notification) async {
    if (!notification.isRead) {
      await _controller.markReadById(notification.id, true);
    }
    if (!mounted) {
      return;
    }
    widget.onOpenNotification(notification);
  }

  String? _platformSeverity(NotificationRecordV1 notification) {
    if (notification.notificationType != 'platform.status') {
      return null;
    }
    final raw = notification.payload['severity'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return null;
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'recovered':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _shortId(String id) {
    final trimmed = id.trim();
    if (trimmed.length <= 8) {
      return trimmed;
    }
    return '${trimmed.substring(0, 8)}...';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final notifications = _controller.items;
        final availableTypes = _controller.availableTypes;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '通知中心',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _controller.loading ? null : _refresh,
                    icon: _controller.loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('刷新'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(label: Text('未读 ${_controller.unreadCount}')),
                  Chip(
                    label: Text(
                      _controller.realtimeConnected
                          ? '实时连接: 在线'
                          : '实时连接: 离线',
                    ),
                    avatar: Icon(
                      _controller.realtimeConnected
                          ? Icons.wifi_tethering
                          : Icons.wifi_tethering_off,
                      size: 16,
                      color: _controller.realtimeConnected
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  FilterChip(
                    label: const Text('仅未读'),
                    selected: _controller.unreadOnly,
                    onSelected: (selected) {
                      _controller.setUnreadOnly(selected);
                      _controller.refresh();
                    },
                  ),
                  FilterChip(
                    label: const Text('仅平台告警'),
                    selected: _controller.platformStatusOnly,
                    onSelected: (selected) {
                      _controller.togglePlatformStatusOnly(selected);
                      _controller.refresh();
                    },
                  ),
                  FilledButton.tonal(
                    onPressed: _controller.mutating || _controller.unreadCount <= 0
                        ? null
                        : _controller.markAllRead,
                    child: const Text('全部标记已读'),
                  ),
                  FilledButton.tonal(
                    onPressed: _controller.mutating
                        ? null
                        : _controller.deleteAllRead,
                    child: const Text('清空已读'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _controller.mutating ? null : _exportPreferences,
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('导出策略 JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _controller.mutating ? null : _importPreferences,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('导入策略 JSON'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '最近实时事件: ${_formatTime(_controller.lastRealtimeEventAt)} · 最近断线: ${_formatTime(_controller.lastRealtimeDisconnectedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                '策略版本: ${_controller.preferencesAudit?.source ?? 'manual'} · 最近更新: ${_formatAuditTime(_controller.preferencesAudit?.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('关键告警强制送达'),
                subtitle: const Text('critical 严重级别不受静音规则影响'),
                value: _controller.deliverCriticalEvenMuted,
                onChanged: _controller.mutating
                    ? null
                    : (value) => _controller.setDeliverCriticalEvenMuted(value),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _controller.mutating
                      ? null
                      : _controller.resetNotificationPreferences,
                  icon: const Icon(Icons.restore),
                  label: const Text('恢复默认通知策略'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '本机：若在成片、发布等流程勾选过「不再提示」而缺少二次确认，可一键恢复（仅当前设备）。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    unawaited(runResetRiskyOperationConfirmPrefsFlow(context));
                  },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('恢复高风险操作确认提示'),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('模板: 默认'),
                    selected: _controller.activeTemplateKey == 'default',
                    onSelected: _controller.mutating
                        ? null
                        : (_) => _controller.applyPreferenceTemplate('default'),
                  ),
                  ChoiceChip(
                    label: const Text('模板: 安静模式'),
                    selected: _controller.activeTemplateKey == 'quiet',
                    onSelected: _controller.mutating
                        ? null
                        : (_) => _controller.applyPreferenceTemplate('quiet'),
                  ),
                  ChoiceChip(
                    label: const Text('模板: 仅事故'),
                    selected: _controller.activeTemplateKey == 'incident',
                    onSelected: _controller.mutating
                        ? null
                        : (_) => _controller.applyPreferenceTemplate('incident'),
                  ),
                  if (_controller.activeTemplateKey == 'custom')
                    const Chip(label: Text('当前: 自定义策略')),
                ],
              ),
              const SizedBox(height: 6),
              if (_controller.mutedTypesSorted.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _controller.mutedTypesSorted
                      .map(
                        (type) => InputChip(
                          label: Text('已静音: $type'),
                          onDeleted: _controller.mutating
                              ? null
                              : () => _controller.setTypeMuted(type, false),
                        ),
                      )
                      .toList(growable: false),
                ),
              if (_controller.mutedTypesSorted.isNotEmpty) const SizedBox(height: 8),
              if (_controller.mutedWorkspaceIdsSorted.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _controller.mutedWorkspaceIdsSorted
                      .map(
                        (workspaceId) => InputChip(
                          label: Text('已静音工作区: ${_shortId(workspaceId)}'),
                          onDeleted: _controller.mutating
                              ? null
                              : () => _controller.setWorkspaceMuted(
                                  workspaceId,
                                  false,
                                ),
                        ),
                      )
                      .toList(growable: false),
                ),
              if (_controller.mutedWorkspaceIdsSorted.isNotEmpty)
                const SizedBox(height: 8),
              if (_controller.mutedProjectIdsSorted.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _controller.mutedProjectIdsSorted
                      .map(
                        (projectId) => InputChip(
                          label: Text('已静音项目: ${_shortId(projectId)}'),
                          onDeleted: _controller.mutating
                              ? null
                              : () => _controller.setProjectMuted(projectId, false),
                        ),
                      )
                      .toList(growable: false),
                ),
              if (_controller.mutedProjectIdsSorted.isNotEmpty)
                const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller.queryController,
                      decoration: const InputDecoration(
                        labelText: '搜索标题/内容',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _controller.refresh(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _controller.notificationType.isEmpty
                        ? ''
                        : _controller.notificationType,
                    onChanged: (value) {
                      _controller.setNotificationType(value ?? '');
                      _controller.refresh();
                    },
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem(value: '', child: Text('全部类型')),
                      ...availableTypes.map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _controller.queryDirty && !_controller.loading
                        ? _controller.refresh
                        : null,
                    child: const Text('应用'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_controller.loading && notifications.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (notifications.isEmpty)
                const Text('暂无通知')
              else
                ...notifications.map(
                  (notification) {
                    final severity = _platformSeverity(notification);
                    final severityColor = _severityColor(severity);
                    final typeMuted = _controller.mutedNotificationTypes.contains(
                      notification.notificationType.trim(),
                    );
                    final workspaceId = notification.workspaceId?.trim();
                    final workspaceMuted = workspaceId != null &&
                        workspaceId.isNotEmpty &&
                        _controller.mutedWorkspaceIds.contains(workspaceId);
                    final projectId = notification.projectId?.trim();
                    final projectMuted = projectId != null &&
                        projectId.isNotEmpty &&
                        _controller.mutedProjectIds.contains(projectId);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        isThreeLine: true,
                        title: Row(
                          children: <Widget>[
                            Expanded(child: Text(notification.title)),
                            if (severity != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: severityColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  severity,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: severityColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${notification.message}\n类型：${notification.notificationType} · ${notification.createdAt.toLocal()}',
                        ),
                        leading: Icon(
                          notification.isRead
                              ? Icons.mark_email_read_outlined
                              : Icons.mark_email_unread_outlined,
                          color: notification.isRead ? Colors.grey : Colors.blue,
                        ),
                        onTap: () => _openNotification(notification),
                        trailing: Wrap(
                          spacing: 4,
                          children: <Widget>[
                            IconButton(
                              tooltip: notification.isRead ? '标记未读' : '标记已读',
                              onPressed: _controller.mutating
                                  ? null
                                  : () => _controller.markReadById(
                                      notification.id,
                                      !notification.isRead,
                                    ),
                              icon: Icon(
                                notification.isRead
                                    ? Icons.drafts_outlined
                                    : Icons.done_outline,
                              ),
                            ),
                            IconButton(
                              tooltip: typeMuted ? '取消静音该类型' : '静音该类型',
                              onPressed: _controller.mutating
                                  ? null
                                  : () => _controller.setTypeMuted(
                                      notification.notificationType,
                                      !typeMuted,
                                    ),
                              icon: Icon(
                                typeMuted
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_off_outlined,
                              ),
                            ),
                            if (workspaceId != null && workspaceId.isNotEmpty)
                              IconButton(
                                tooltip: workspaceMuted
                                    ? '取消静音该工作区'
                                    : '静音该工作区',
                                onPressed: _controller.mutating
                                    ? null
                                    : () => _controller.setWorkspaceMuted(
                                        workspaceId,
                                        !workspaceMuted,
                                      ),
                                icon: Icon(
                                  workspaceMuted
                                      ? Icons.workspaces_outline
                                      : Icons.domain_disabled_outlined,
                                ),
                              ),
                            if (projectId != null && projectId.isNotEmpty)
                              IconButton(
                                tooltip: projectMuted ? '取消静音该项目' : '静音该项目',
                                onPressed: _controller.mutating
                                    ? null
                                    : () => _controller.setProjectMuted(
                                        projectId,
                                        !projectMuted,
                                      ),
                                icon: Icon(
                                  projectMuted
                                      ? Icons.folder_open_outlined
                                      : Icons.folder_off_outlined,
                                ),
                              ),
                            IconButton(
                              tooltip: '删除通知',
                              onPressed: _controller.mutating
                                  ? null
                                  : () => _controller.deleteById(notification.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              if (_controller.hasMore)
                FilledButton.tonal(
                  onPressed: _controller.loadingMore ? null : _controller.loadMore,
                  child: Text(_controller.loadingMore ? '加载中...' : '加载更多'),
                ),
            ],
          ),
        );
      },
    );
  }
}
