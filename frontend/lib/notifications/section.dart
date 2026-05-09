import 'package:flutter/material.dart';

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
  final _searchController = TextEditingController();
  String _typeFilter = 'all';
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    Text('通知中心', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '统一汇总任务完成、workspace 邀请与技能变更，并保留已读状态。',
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
                label: const Text('全部已读'),
              ),
              const SizedBox(width: 4),
              const RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: '本机客户端偏好（短视频等高风险「不再提示」）',
              ),
            ],
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
                label: Text('未读 ${widget.controller.unreadCount}'),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _typeFilter,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(value: 'job', child: Text('任务')),
                    DropdownMenuItem(value: 'workspace', child: Text('团队')),
                    DropdownMenuItem(value: 'skill', child: Text('技能')),
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
                  decoration: const InputDecoration(
                    labelText: '搜索标题 / 内容 / file / job',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.controller.loading
                    ? null
                    : widget.controller.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
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
                '当前筛选条件下没有通知。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...filtered.map((item) => _buildNotificationTile(context, item)),
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
                label: const Text('加载更多'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
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
                  '未读',
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
                '${_notificationTypeLabel(item.notificationType)} · ${_formatDateTime(item.createdAt)}',
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
                child: const Text('标记已读'),
              ),
            FilledButton.tonal(
              onPressed: () {
                if (item.isUnread) {
                  widget.controller.markRead(item);
                }
                widget.onOpenNotification(item);
              },
              child: const Text('打开'),
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
    return Icons.notifications_none_outlined;
  }

  String _notificationTypeLabel(String notificationType) {
    switch (notificationType) {
      case 'job_succeeded':
        return '任务完成';
      case 'job_failed':
        return '任务失败';
      case 'job_cancelled':
        return '任务取消';
      case 'workspace_invite_created':
        return '邀请已创建';
      case 'workspace_invite_resent':
        return '邀请已重发';
      case 'workspace_invite_revoked':
        return '邀请已撤销';
      case 'workspace_invite_accepted':
        return '邀请已接受';
      case 'skill_change':
        return '技能变更';
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
}
